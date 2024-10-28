import logging
import traceback

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from src.api.v1 import routers

logger = logging.getLogger(__name__)


def start_app():
    service_weather_app = FastAPI(title="service-weather", debug=True)
    register_routes(service_weather_app)
    origins = ["*"]
    service_weather_app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    return service_weather_app


def register_routes(service_weather_app):
    """
    Register application routes
    """
    service_weather_app.include_router(routers)
    @service_weather_app.get("/health")
    async def health_check():
        return JSONResponse(status_code=200, content={"status": "ok"})


app = start_app()


@app.on_event("startup")
async def startup():
    pass


@app.on_event("shutdown")
async def shutdown():
    pass


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request, exc):
    traceback_data = traceback.format_exception(exc)
    if exc.status_code >= 500:
        logger.error(f"traceback {''.join(traceback_data)}")
    elif exc.status_code >= 400:
        logger.warning(f"traceback {''.join(traceback_data)}")
    else:
        logger.info(f"traceback {''.join(traceback_data)}")
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    traceback_data = traceback.format_exception(exc)
    logger.warning(f"traceback {''.join(traceback_data)}")
    return JSONResponse(status_code=400, content={"detail": exc.errors()})
