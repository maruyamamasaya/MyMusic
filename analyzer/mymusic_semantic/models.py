"""Read-only reuse of the already verified PoC weights and frontend. No downloads."""
from __future__ import annotations

import gc
import inspect
import json
import os
import subprocess
import sys
import time

from .safety import ANALYZER, digest, fingerprint

os.environ['ORT_DISABLE_TELEMETRY']='1'
POC=ANALYZER/'poc'
sys.path.insert(0,str(POC))
from engine import average_channels, mel_spectrogram
from prepare_models import CHECKSUMS
sys.path.insert(0,str(POC/'human_eval'))
from heads import HeadBank, manifest as binary_manifest
from mymusic_analyzer.audio import _segment_offsets

SEMANTIC_MAPPING = {
    'piano':('tags','piano'), 'electronic':('tags','electronic'),
    'ambient':('tags','ambient'), 'dark':('mood','dark'),
    'vocal':('voice_instrumental','voice'), 'instrumental':('voice_instrumental','instrumental'),
    'aggressive':('mood_aggressive','aggressive'), 'calm':('mood_relaxed','relaxed'),
}


def verified_files(groups):
    result={}
    for group in groups:
        for ext in ('json','onnx'):
            name=f'{group}.{ext}';path=POC/'models'/name
            if digest(path)!=CHECKSUMS[name]:
                raise ValueError(f'Existing model failed checksum: {path}')
            result[name]=CHECKSUMS[name]
    return result


def embedding_spec():
    return dict(format=1,backbone=verified_files(('discogs',)),dimension=1280,dtype='float32',
        frontend='verified PoC legacy mel; no terminal-frame candidate promotion',
        frontendSource=fingerprint(inspect.getsource(mel_spectrogram)),
        monoSource=fingerprint(inspect.getsource(average_channels)),
        offsetsSource=fingerprint(inspect.getsource(_segment_offsets)),
        nativeDecode='ffmpeg f32le/native rate/arithmetic channel mean',
        resample='soxr_hq native->22050->16000',windowSeconds=30,segments=3,
        patchFrames=128,patchHop=62,batch=8,threads=2)


def heads_spec():
    return dict(revision='semantic-heads-v2-live-library',generic=verified_files(('tags','mood')),
        expectedBackbone=CHECKSUMS['discogs.onnx'],
        binary=binary_manifest(),mapping=SEMANTIC_MAPPING,aggregation='mean per-patch probabilities',
        drumAndBass='cached Discogs Electronic---Drum n Bass',
        dsp='energy/tempo copied when a matching production baseline value exists',analysisVersion=2)


def session(path):
    import onnxruntime as ort
    ort.disable_telemetry_events()
    options=ort.SessionOptions()
    options.intra_op_num_threads=2
    options.inter_op_num_threads=1
    options.execution_mode=ort.ExecutionMode.ORT_SEQUENTIAL
    return ort.InferenceSession(str(path),options,providers=['CPUExecutionProvider'])


class Backbone:
    """Only this class can read audio. HeadRunner cannot instantiate it."""
    def __init__(self):
        self.model=session(POC/'models/discogs.onnx')
        self.audio_reads=0
        self.decode_calls=0

    def extract(self,path,duration):
        import numpy as np
        import librosa
        self.audio_reads+=1
        started=time.perf_counter()
        timing=dict(decode=0.,preprocessing=0.,inference=0.,dsp=0.)
        start=time.perf_counter()
        probe=subprocess.run(['ffprobe','-v','error','-select_streams','a:0',
            '-show_entries','stream=channels,sample_rate','-of','json',str(path)],capture_output=True,timeout=30,check=True)
        stream=json.loads(probe.stdout)['streams'][0]
        channels,rate=int(stream['channels']),int(stream['sample_rate'])
        if not 1<=channels<=8 or not 8000<=rate<=192000:
            raise ValueError('Unsupported channel count/sample rate')
        timing['decode']+=time.perf_counter()-start
        embeddings=[];sums=np.zeros(400,dtype=np.float64);counts=[]
        offsets=_segment_offsets(duration,30.,3)
        for offset in offsets:
            start=time.perf_counter()
            self.decode_calls+=1
            decoded=subprocess.run(['ffmpeg','-v','error','-nostdin','-threads','1',
                '-ss',str(offset),'-i',str(path),'-t',str(min(30.,duration-offset)),
                '-map','0:a:0','-vn','-ac',str(channels),'-ar',str(rate),'-f','f32le','pipe:1'],
                capture_output=True,timeout=60,check=True)
            mono=average_channels(decoded.stdout,channels)
            del decoded
            y22=librosa.resample(mono,orig_sr=rate,target_sr=22050,res_type='soxr_hq')
            del mono
            timing['decode']+=time.perf_counter()-start
            start=time.perf_counter()
            y16=librosa.resample(y22,orig_sr=22050,target_sr=16000,res_type='soxr_hq')
            del y22
            if not np.isfinite(y16).all():
                raise ValueError('Non-finite audio samples')
            mel=mel_spectrogram(y16)
            del y16
            starts=range(0,len(mel)-128+1,62)
            if not len(starts):
                raise ValueError('No complete model patches')
            timing['preprocessing']+=time.perf_counter()-start
            counts.append(len(starts))
            for batch_start in range(0,len(starts),8):
                batch=np.stack([mel[s:s+128] for s in starts[batch_start:batch_start+8]])
                start=time.perf_counter()
                styles,embedded=self.model.run(['activations','embeddings'],{'melspectrogram':batch})
                timing['inference']+=time.perf_counter()-start
                if (embedded.shape!=(len(batch),1280) or styles.shape!=(len(batch),400)
                        or not np.isfinite(embedded).all() or not np.isfinite(styles).all()
                        or np.any(styles<0) or np.any(styles>1)):
                    raise ValueError('Unexpected backbone output')
                embeddings.append(embedded.astype(np.float32,copy=True))
                sums+=styles.sum(axis=0,dtype=np.float64)
            del mel,batch,styles,embedded
            gc.collect()
        arrays=dict(embeddings=np.concatenate(embeddings),discogs_mean=sums/sum(counts),
                    segment_offsets=np.asarray(offsets,dtype=np.float64),
                    segment_patch_counts=np.asarray(counts,dtype=np.int32))
        timing['total']=time.perf_counter()-started
        return arrays,dict(timing=timing,channels=channels,nativeRate=rate,patches=sum(counts),
                           dspSource='copied from baseline when available; no DSP reanalysis')


class HeadRunner:
    def __init__(self):
        self.binary=HeadBank()
        self.sessions={g:session(POC/'models'/f'{g}.onnx') for g in ('tags','mood')}
        self.labels={g:json.loads((POC/'models'/f'{g}.json').read_text())['classes'] for g in ('tags','mood','discogs')}
        for g,model in self.sessions.items():
            if model.get_inputs()[0].shape[-1]!=1280 or model.get_outputs()[0].shape[-1]!=len(self.labels[g]):
                raise ValueError('Generic head schema mismatch')

    def predict(self,arrays,dsp):
        import numpy as np
        embedded=arrays['embeddings']
        labels=self.binary.predict(embedded)
        for group,model in self.sessions.items():
            total=np.zeros(len(self.labels[group]),dtype=np.float64)
            for start in range(0,len(embedded),8):
                values=model.run(['activations'],{'embeddings':embedded[start:start+8]})[0]
                if not np.isfinite(values).all() or np.any(values<0) or np.any(values>1):
                    raise ValueError('Invalid generic head probabilities')
                total+=values.sum(axis=0,dtype=np.float64)
            labels[group]=dict(zip(self.labels[group],(total/len(embedded)).tolist()))
        labels['discogs']=dict(zip(self.labels['discogs'],arrays['discogs_mean'].tolist()))
        features={k:round(float(labels[group][label]),6) for k,(group,label) in SEMANTIC_MAPPING.items()}
        features['drumAndBass']=round(labels['discogs']['Electronic---Drum n Bass'],6)
        for key in ('energy','tempo'):
            if key in dsp:
                features[key]=dsp[key]
        return features,labels
