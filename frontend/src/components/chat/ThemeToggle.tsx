import { useEffect, useMemo, useState } from "react";
import { Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";
import { getStoredThemeMode, setThemeMode, type ThemeMode } from "@/lib/theme";

export function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode>(() => getStoredThemeMode() ?? "dark");

  useEffect(() => {
    setThemeMode(mode);
  }, [mode]);

  const isDark = useMemo(() => mode === "dark", [mode]);

  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      className="rounded-xl hover:bg-muted/60"
      onClick={() => setMode(isDark ? "light" : "dark")}
      title={isDark ? "Switch to light mode" : "Switch to dark mode"}
    >
      {isDark ? <Moon className="h-4 w-4" /> : <Sun className="h-4 w-4" />}
      <span className="sr-only">Toggle theme</span>
    </Button>
  );
}


