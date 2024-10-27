from fastapi import APIRouter

routers = APIRouter(
    prefix="/weather",
    # route_class=ProtectedAPIRoute,
)


@routers.get("/")
async def get_today_weather():
    return {"weather": "sunny"}
