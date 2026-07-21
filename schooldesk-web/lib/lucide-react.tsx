import type { CSSProperties } from "react";

export type LucideProps = {
  size?: number;
  className?: string;
  style?: CSSProperties;
};

function icon(symbol: string) {
  return function Icon({ size = 16, className, style }: LucideProps) {
    return (
      <span
        aria-hidden
        className={className}
        style={{
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          width: size,
          height: size,
          fontSize: Math.max(10, Math.round(size * 0.8)),
          lineHeight: 1,
          ...style,
        }}
      >
        {symbol}
      </span>
    );
  };
}

export const Activity = icon("◔");
export const BellRing = icon("◌");
export const Building2 = icon("▣");
export const CalendarClock = icon("◷");
export const CalendarDays = icon("▦");
export const ChartNoAxesCombined = icon("◫");
export const CheckCircle2 = icon("✓");
export const ChevronRight = icon("›");
export const CircleAlert = icon("!");
export const ClipboardCheck = icon("☑");
export const Download = icon("↓");
export const Eye = icon("◉");
export const FileSpreadsheet = icon("▤");
export const FileText = icon("≣");
export const Globe2 = icon("◍");
export const GraduationCap = icon("⌂");
export const Info = icon("i");
export const LayoutDashboard = icon("☷");
export const LoaderCircle = icon("◌");
export const MessageSquareMore = icon("✉");
export const Pencil = icon("✎");
export const Plus = icon("+");
export const ReceiptIndianRupee = icon("₹");
export const RefreshCw = icon("↻");
export const RotateCcw = icon("↺");
export const Search = icon("⌕");
export const Send = icon("➚");
export const ShieldCheck = icon("✓");
export const Trash2 = icon("×");
export const UsersRound = icon("◍");
export const WalletCards = icon("▭");
export const X = icon("×");
