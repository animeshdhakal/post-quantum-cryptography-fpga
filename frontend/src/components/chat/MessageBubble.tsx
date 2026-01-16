import { cn } from "@/lib/utils";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface MessageBubbleProps {
    content: string;
    sender: {
        id: number;
        username: string;
    };
    timestamp: string;
    isOwn: boolean;
    showAvatar?: boolean;
    className?: string;
    is_read?: boolean;
}

export function MessageBubble({
    content,
    sender,
    timestamp,
    isOwn,
    showAvatar = true,
    className,
    is_read = false
}: MessageBubbleProps) {
    const getAvatarColor = (username: string) => {
        const colors = [
            'bg-rose-500', 'bg-orange-500', 'bg-amber-500', 'bg-yellow-500',
            'bg-emerald-500', 'bg-teal-500', 'bg-cyan-500', 'bg-sky-500',
            'bg-blue-500', 'bg-indigo-500', 'bg-violet-500', 'bg-purple-500'
        ];
        let hash = 0;
        for (let i = 0; i < username.length; i++) {
            hash = username.charCodeAt(i) + ((hash << 5) - hash);
        }
        return colors[Math.abs(hash) % colors.length];
    };

    const formatTime = (timestamp: string) => {
        const date = new Date(timestamp);
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    };

    return (
        <div className={cn(
            "flex gap-3 mb-2 animate-message-in items-end",
            isOwn ? "flex-row-reverse" : "flex-row",
            className
        )}>
            {/* Avatar for received messages */}
            {!isOwn && (
                <div className="flex-shrink-0 w-8">
                    {showAvatar ? (
                        <Avatar className="h-8 w-8 shadow-sm">
                            <AvatarFallback className={cn("text-white text-[10px] font-bold uppercase", getAvatarColor(sender.username))}>
                                {sender.username.charAt(0)}
                            </AvatarFallback>
                        </Avatar>
                    ) : (
                        <div className="w-8" />
                    )}
                </div>
            )}

            {/* Message Content Container */}
            <div className={cn(
                "flex flex-col max-w-[70%]",
                isOwn ? "items-end" : "items-start"
            )}>
                {/* Sender Name (optional, for groups) */}
                {!isOwn && showAvatar && (
                    <span className="text-[11px] font-semibold text-muted-foreground ml-1 mb-1">
                        {sender.username}
                    </span>
                )}

                {/* Bubble */}
                <div className={cn(
                    "relative px-4 py-2.5 shadow-sm transition-all",
                    isOwn
                        ? "bg-primary text-primary-foreground rounded-2xl rounded-br-none"
                        : "bg-muted text-foreground rounded-2xl rounded-bl-none border border-border/50"
                )}>
                    <p className="text-sm leading-relaxed break-words whitespace-pre-wrap">
                        {content}
                    </p>

                    {/* Inner timestamp/status for sent messages */}
                    <div className={cn(
                        "flex items-center gap-1 mt-1 justify-end opacity-70",
                        isOwn ? "text-primary-foreground" : "text-muted-foreground"
                    )}>
                        <span className="text-[9px] font-medium leading-none">
                            {formatTime(timestamp)}
                        </span>
                        {isOwn && (
                            <div className="flex items-center ml-0.5">
                                {is_read ? (
                                    <CheckCheck className="w-3.5 h-3.5 text-blue-400 stroke-[3px]" />
                                ) : (
                                    <Check className="w-3.5 h-3.5 opacity-70 stroke-[3px]" />
                                )}
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Spacer for own messages to align with received ones if needed */}
            {isOwn && !showAvatar && <div className="w-8" />}
        </div>
    );
}

import { Check, CheckCheck } from "lucide-react";
