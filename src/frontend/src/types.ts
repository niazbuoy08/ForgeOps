export interface HealthStatus {
  status: string;
  environment: string;
  version: string;
}

export interface ApiHealthStatus extends HealthStatus {
  database: string;
}

export interface Item {
  id: number;
  name: string;
  description: string | null;
  created_at: string;
}
