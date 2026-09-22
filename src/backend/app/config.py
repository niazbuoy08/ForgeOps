"""Application configuration loaded from environment variables.

All values are injected via Kubernetes ConfigMaps/Secrets at deploy time.
Nothing here is hardcoded to a real value - see kubernetes/helm/backend/templates
and the Secrets Store CSI Driver SecretProviderClass for how DB credentials
are populated from Azure Key Vault.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App metadata
    app_name: str = "aks-gitops-platform-backend"
    environment: str = "dev"
    app_version: str = "0.0.0-local"

    # CORS
    cors_allowed_origins: str = "*"

    # Database - populated from Key Vault via Secrets Store CSI Driver
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "appdb"
    db_user: str = "postgres"
    db_password: str = "postgres"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
