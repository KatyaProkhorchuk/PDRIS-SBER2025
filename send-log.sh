for i in {1..50}; do
  curl -X POST http://localhost:80/log -H "Content-Type: application/json" -d '{"message": "test "}'
done