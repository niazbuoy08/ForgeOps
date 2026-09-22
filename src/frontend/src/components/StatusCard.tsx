interface StatusCardProps {
  label: string;
  value: string;
  tone: "ok" | "warn" | "error" | "neutral";
}

const toneClass: Record<StatusCardProps["tone"], string> = {
  ok: "status-card status-card--ok",
  warn: "status-card status-card--warn",
  error: "status-card status-card--error",
  neutral: "status-card status-card--neutral",
};

export default function StatusCard({ label, value, tone }: StatusCardProps) {
  return (
    <div className={toneClass[tone]}>
      <span className="status-card__label">{label}</span>
      <span className="status-card__value">{value}</span>
    </div>
  );
}
