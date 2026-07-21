"use client";

import React, { Component } from "react";
import { RefreshCw, TriangleAlert } from "lucide-react";

interface ErrorBoundaryProps {
  children: React.ReactNode;
  /** Optional custom fallback UI. If omitted, a default card is shown. */
  fallback?: React.ReactNode;
  /** Optional label shown in the error card heading (default: "Something went wrong") */
  label?: string;
}

interface ErrorBoundaryState {
  hasError: boolean;
  message: string;
}

/**
 * React error boundary that catches render/lifecycle errors in child components.
 * Prevents white-screen crashes by rendering a friendly fallback card.
 * Wrap critical sections (portal modules, pages) in this boundary.
 */
export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, message: "" };
  }

  static getDerivedStateFromError(error: unknown): ErrorBoundaryState {
    const message =
      error instanceof Error ? error.message : "An unexpected error occurred.";
    return { hasError: true, message };
  }

  componentDidCatch(error: unknown, info: React.ErrorInfo) {
    // Log to console in development; swap to Sentry.captureException(error) when integrated.
    console.error("[ErrorBoundary] Caught error:", error, info.componentStack);
  }

  handleReset = () => {
    this.setState({ hasError: false, message: "" });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;

      return (
        <div className="error-boundary-card" role="alert">
          <span className="error-boundary-icon">
            <TriangleAlert size={22} />
          </span>
          <div>
            <b>{this.props.label ?? "Something went wrong"}</b>
            <p>{this.state.message}</p>
          </div>
          <button
            className="secondary-button"
            onClick={this.handleReset}
            type="button"
          >
            <RefreshCw size={15} /> Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

/**
 * Lightweight per-module error boundary for the portal.
 * A failed module will show a compact error card without crashing the sidebar or topbar.
 */
export function PortalErrorBoundary({ children }: { children: React.ReactNode }) {
  return (
    <ErrorBoundary label="Module error">
      {children}
    </ErrorBoundary>
  );
}
