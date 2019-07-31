package generate

// +build ignore

//go:generate bash generate_gateway.sh ../frontend/frontend.proto
//go:generate bash generate_gateway.sh ../backend/backend.proto
