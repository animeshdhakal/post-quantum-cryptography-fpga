import { cn } from "@/lib/utils";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Users, Check } from "lucide-react";

interface ChatListItemProps {
    id: number;
    name: string;
    lastMessage?: string;
    timestamp?: string;
    unreadCount?: number;
    isActive?: boolean;
    isGroup?: boolean;
    participantCount?: number;
    onClick?: () => void;
    isOnline?: boolean;
    className?: string;
}

export function ChatListItem({
    name,
    lastMessage,
    timestamp,
    unreadCount = 0,
    isActive = false,
    isGroup = false,
    participantCount,
    onClick,
    isOnline = false,
    className
}: ChatListItemProps) {
    const getAvatarColor = (name: string) => {
        const colors = [
            'from-rose-500 to-pink-600',
            'from-orange-500 to-amber-600',
            'from-emerald-500 to-teal-600',
            'from-blue-500 to-indigo-600',
            'from-violet-500 to-purple-600'
        ];
        let hash = 0;
        for (let i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        }
        return colors[Math.abs(hash) % colors.length];
    };

    const formatTime = (timestamp: string) => {
        try {
            const date = new Date(timestamp);
            const now = new Date();
            const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60);

            if (isNaN(date.getTime())) return '';

            if (diffInHours < 24 && date.getDate() === now.getDate()) {
                return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: true });
            } else if (diffInHours < 48) {
                return 'Yesterday';
            } else if (diffInHours < 168) {
                return date.toLocaleDateString([], { weekday: 'short' });
            } else {
                return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
            }
        } catch {
            return '';
        }
    };

    return (
        <button
            onClick={onClick}
            className={cn(
                "w-full flex items-center gap-4 px-4 py-3.5 transition-all duration-200 border-none rounded-xl mx-2 my-1 max-w-[calc(100%-16px)]",
                isActive
                    ? "bg-primary/10 text-primary shadow-sm ring-1 ring-primary/20"
                    : "hover:bg-muted/80 text-foreground",
                className
            )}
        >
            {/* Avatar */}
            <div className="relative flex-shrink-0">
                <Avatar className="h-12 w-12 border-2 border-background shadow-md">
                    <AvatarFallback className={cn("bg-gradient-to-br text-white font-bold text-sm", getAvatarColor(name))}>
                        {isGroup ? (
                            <Users className="h-5 w-5" />
                        ) : (
                            name.charAt(0).toUpperCase()
                        )}
                    </AvatarFallback>
                </Avatar>
                {!isGroup && isOnline && (
                    <div className="absolute -right-0.5 -bottom-0.5 h-3.5 w-3.5 rounded-full bg-green-500 border-2 border-background" />
                )}
            </div>

            {/* Content */}
            <div className="flex-1 min-w-0 flex flex-col items-start gap-1">
                {/* Name and timestamp */}
                <div className="flex items-center justify-between w-full">
                    <h3 className={cn(
                        "font-bold text-[14px] truncate leading-tight tracking-tight",
                        isActive ? "text-primary" : "text-foreground"
                    )}>
                        {name}
                        {isGroup && participantCount && (
                            <span className="ml-1.5 text-[10px] text-muted-foreground font-medium opacity-70">
                                {participantCount} participants
                            </span>
                        )}
                    </h3>
                    {timestamp && (
                        <span className={cn(
                            "text-[11px] font-medium opacity-60 ml-2 whitespace-nowrap",
                            unreadCount > 0 && !isActive ? "text-primary opacity-100" : "text-muted-foreground"
                        )}>
                            {formatTime(timestamp)}
                        </span>
                    )}
                </div>

                {/* Last message and unread badge */}
                <div className="flex items-center justify-between w-full h-5">
                    <p className={cn(
                        "text-[13px] truncate leading-none",
                        unreadCount > 0 && !isActive ? "text-foreground font-semibold" : "text-muted-foreground font-medium"
                    )}>
                        {lastMessage || "Start a conversation..."}
                    </p>

                    {unreadCount > 0 ? (
                        <div className="bg-primary px-1.5 py-0.5 min-w-[18px] h-[18px] rounded-full flex items-center justify-center shadow-lg shadow-primary/30 ml-2">
                            <span className="text-[10px] text-primary-foreground font-bold leading-none">
                                {unreadCount > 99 ? '99+' : unreadCount}
                            </span>
                        </div>
                    ) : isActive && (
                        <Check className="h-3 w-3 text-primary opacity-60 ml-2" />
                    )}
                </div>
            </div>
        </button>
    );
}
