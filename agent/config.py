"""
Configuration management for the AI agent.
"""

import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from dotenv import load_dotenv

def _first_env(*names: str) -> Optional[str]:
    for name in names:
        value = os.getenv(name)
        if value:
            return value
    return None


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Required fields for local mode
    api_key: Optional[str] = Field(
        default_factory=lambda: _first_env(
            "API_KEY",
            "OPENAI_API_KEY",
            "CODEX_API_KEY",
            "ANTHROPIC_API_KEY",
            "GEMINI_API_KEY",
            "CURSOR_API_KEY",
        )
    )
    model: str = Field(
        default_factory=lambda: _first_env(
            "MODEL",
            "OPENAI_MODEL",
            "CURSOR_MODEL",
            "CODEX_MODEL",
            "CLAUDE_MODEL",
            "GEMINI_MODEL",
        )
        or "composer-2.5"
    )
    detector: str = Field(default_factory=lambda: _first_env("DETECTOR", "AGENT_DETECTOR") or "cursor")
    log_level: str = "INFO"
    log_file: str = "agent.log"
    
    # Additional fields for server mode
    agentarena_api_key: Optional[str] = Field(None, env="AGENTARENA_API_KEY")
    webhook_auth_token: Optional[str] = Field(None, env="WEBHOOK_AUTH_TOKEN")
    data_dir: Optional[str] = Field("./data", env="DATA_DIR")
    
def load_config() -> Settings:
    """Load and return application configuration."""
    load_dotenv(override=True)
    return Settings() 
