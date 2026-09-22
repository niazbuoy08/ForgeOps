import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import App from "../App";

describe("App", () => {
  beforeEach(() => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        if (url === "/health") {
          return new Response(JSON.stringify({ status: "ok", environment: "dev", version: "1" }));
        }
        if (url.toString().includes("/api/health")) {
          return new Response(
            JSON.stringify({ status: "ok", environment: "dev", version: "1", database: "ok" }),
          );
        }
        if (url.toString().includes("/api/items")) {
          return new Response(JSON.stringify([]));
        }
        return new Response("not found", { status: 404 });
      }),
    );
  });

  it("renders the dashboard title", async () => {
    render(<App />);
    expect(await screen.findByText("AKS GitOps Platform")).toBeInTheDocument();
  });

  it("shows the empty state when there are no items", async () => {
    render(<App />);
    expect(await screen.findByText(/No records yet/i)).toBeInTheDocument();
  });
});
