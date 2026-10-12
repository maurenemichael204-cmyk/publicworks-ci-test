# mock_server.py —— 本地联调 Mock（返回虚构数据）
# 运行：python -m pip install fastapi uvicorn
#      uvicorn mock_server:app --host 127.0.0.1 --port 8000
from typing import Optional
from fastapi import FastAPI, Header, HTTPException

app = FastAPI()
TOKEN = "dev-only-token"


def authorize(value: Optional[str]):
    if value != f"Bearer {TOKEN}":
        raise HTTPException(status_code=401, detail="Unauthorized")


@app.get("/v1/uids")
def get_uids(authorization: Optional[str] = Header(default=None)):
    authorize(authorization)
    return {"uids": [{"uid": "mock_uid_001"}]}


@app.get("/v1/users/{uid}/public-works")
def get_works(uid: str, authorization: Optional[str] = Header(default=None)):
    authorize(authorization)
    return {
        "uid": uid,
        "fetchedAt": "2026-10-12T12:00:00Z",
        "works": [
            {
                "id": "mock-work-001",
                "title": "虚构的测试作品一",
                "url": "https://example.com/public-work",
                "publishedAt": "2026-10-01T10:00:00Z"
            },
            {
                "id": "mock-work-002",
                "title": "虚构的测试作品二",
                "url": "https://example.com/public-work-2",
                "publishedAt": "2026-10-05T10:00:00Z"
            }
        ]
    }
