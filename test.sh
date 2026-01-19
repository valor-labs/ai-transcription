#!/bin/bash

set -e

./run-locally.sh
curl -X POST http://localhost:8080/ -H 'Content-Type: application/json' -d '{"message": {"attributes": {"eventType": "OBJECT_FINALIZE", "bucketId": "transcription-ai-12dfas13-input"}, "data": "eyJidWNrZXQiOiAidHJhbnNjcmlwdGlvbi1haS0xMmRmYXMxMy1pbnB1dCIsICJuYW1lIjogIjIwODI1Mzk2OS03ZTM1ZmUyYS03NTQxLTQzNGEtYWU5MS04ZTkxOTU0MDU1NWQud2F2In0=", "messageId": "1234567890123456", "publishTime": "2025-03-06T12:00:00.000Z"}, "subscription": "projects/my-project/subscriptions/my-subscription"}'