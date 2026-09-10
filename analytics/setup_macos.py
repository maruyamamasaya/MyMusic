from setuptools import setup


setup(
    app=["desktop.py"],
    name="MyMusic Analytics",
    options={
        "py2app": {
            "argv_emulation": False,
            "resources": ["web"],
            "packages": ["app", "importer", "fastapi", "uvicorn", "multipart", "pydantic"],
            "plist": {
                "CFBundleDisplayName": "MyMusic Analytics",
                "CFBundleName": "MyMusic Analytics",
                "CFBundleIdentifier": "local.mymusic.analytics",
                "NSHighResolutionCapable": True,
            },
        }
    },
    setup_requires=["py2app"],
)
