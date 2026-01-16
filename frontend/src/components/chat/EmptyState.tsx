import { MessageSquare } from "lucide-react";

interface EmptyStateProps {
    icon?: React.ReactNode;
    title: string;
    description?: string;
}

export function EmptyState({ icon, title, description }: EmptyStateProps) {
    return (
        <div className="flex flex-col items-center justify-center h-full p-8 text-center">
            <div className="w-20 h-20 bg-muted/30 rounded-full flex items-center justify-center mb-4">
                {icon || <MessageSquare className="h-10 w-10 text-muted-foreground/50" />}
            </div>
            <h3 className="text-lg font-semibold mb-2">{title}</h3>
            {description && (
                <p className="text-sm text-muted-foreground max-w-sm">
                    {description}
                </p>
            )}
        </div>
    );
}
