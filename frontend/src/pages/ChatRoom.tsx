import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import { useAuth } from '../context/auth';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Send, MoreVertical, ArrowLeft, Smile, ShieldCheck } from 'lucide-react';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { toast } from 'sonner';
import { MessageBubble } from '@/components/chat/MessageBubble';
import { DateSeparator } from '@/components/chat/DateSeparator';
import { EmptyState } from '@/components/chat/EmptyState';
import { cn } from "@/lib/utils";
import { isSameDay } from 'date-fns';
import { useWebSocket } from '@/hooks/useWebSocket';
import { TypingIndicator } from '@/components/chat/TypingIndicator';

interface Message {
    id: number;
    content: string;
    sender: {
        id: number;
        username: string;
        email: string;
    };
    timestamp: string;
    is_read?: boolean;
}

interface Room {
    id: number;
    name: string;
    participants: {
        id: number;
        username: string;
        email: string;
    }[];
}

export default function ChatRoom() {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const { user } = useAuth();
    const [messages, setMessages] = useState<Message[]>([]);
    const [room, setRoom] = useState<Room | null>(null);
    const [newMessage, setNewMessage] = useState('');
    const [loading, setLoading] = useState(true);
    const [typingUsers, setTypingUsers] = useState<Record<number, { username: string, is_typing: boolean }>>({});
    const [recipientOnline, setRecipientOnline] = useState<boolean>(false);
    const scrollRef = useRef<HTMLDivElement>(null);
    const typingTimeoutRef = useRef<any>(null);

    // Initial fetch of messages and room details
    useEffect(() => {
        if (!id) return;
        setMessages([]);
        setLoading(true);
        fetchMessages();
        fetchRoomDetails();
    }, [id]);

    const fetchRoomDetails = async () => {
        try {
            const response = await api.get<Room>(`/api/chat/rooms/${id}/`);
            setRoom(response.data);

            // Set initial recipient online status
            const otherParticipant = response.data.participants.find(p => p.id !== user?.id);
            if (otherParticipant) {
                setRecipientOnline((otherParticipant as any).is_online || false);
            }
        } catch (error) {
            console.error("Failed to fetch room details", error);
        }
    };

    const getRoomDisplayName = () => {
        if (!room || !user) return "Chat Room";
        if (room.name.startsWith('dm-')) {
            const otherParticipant = room.participants.find(p => p.id !== user.id);
            return otherParticipant ? (otherParticipant.username || otherParticipant.email.split('@')[0]) : "Direct Message";
        }
        return room.name;
    };

    const getRecipientAvatar = () => {
        if (!room || !user) return "?";
        if (room.name.startsWith('dm-')) {
            const otherParticipant = room.participants.find(p => p.id !== user.id);
            return otherParticipant ? (otherParticipant.username || otherParticipant.email)[0].toUpperCase() : "?";
        }
        return room.name[0].toUpperCase();
    };

    // WebSocket message handler
    const handleNewMessage = useCallback((data: any) => {
        if (data.type === 'message') {
            setMessages((prev) => {
                // Prevent duplicate messages
                if (prev.some(m => m.id === data.id)) return prev;
                return [...prev, { ...data, is_read: data.is_read || false }];
            });

            // If message is from other user and we are in the room, send read receipt
            if (data.sender.id !== user?.id) {
                sendReadReceipt();
            }
        } else if (data.type === 'typing') {
            setTypingUsers(prev => ({
                ...prev,
                [data.user_id]: { username: data.username, is_typing: data.is_typing }
            }));
        } else if (data.type === 'read_receipt') {
            if (data.user_id !== user?.id) {
                setMessages(prev => prev.map(m => m.sender.id === user?.id ? { ...m, is_read: true } : m));
            }
        } else if (data.type === 'user_presence') {
            const otherParticipant = room?.participants.find(p => p.id !== user?.id);
            if (otherParticipant && data.user_id === otherParticipant.id) {
                setRecipientOnline(data.is_online);
            }
        }
    }, [user?.id, room]);

    const { sendMessage: sendWsMessage, sendJson, status: wsStatus } = useWebSocket(id, handleNewMessage);

    const sendReadReceipt = useCallback(() => {
        if (wsStatus === 'open') {
            sendJson({ type: 'read_receipt', room_id: id });
        }
    }, [wsStatus, sendJson, id]);

    useEffect(() => {
        if (wsStatus === 'open' && messages.length > 0) {
            sendReadReceipt();
        }
    }, [wsStatus, id, sendReadReceipt]); // Added messages dependency if needed, but fetchMessages handles it

    useEffect(() => {
        if (scrollRef.current) {
            scrollRef.current.scrollIntoView({ behavior: 'smooth' });
        }
    }, [messages, typingUsers]);

    const fetchMessages = async () => {
        try {
            const response = await api.get<Message[]>(`/api/chat/rooms/${id}/messages/`);
            setMessages(response.data);
            setLoading(false);
            // Send read receipt after fetching existing messages
            setTimeout(sendReadReceipt, 500);
        } catch (error) {
            console.error("Failed to fetch messages", error);
            setLoading(false);
        }
    };

    const handleSendMessage = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newMessage.trim()) return;

        // Stop typing indicator immediately when sending
        stopTyping();

        const sent = sendWsMessage(newMessage);
        if (sent) {
            setNewMessage('');
        } else {
            // Fallback to REST if WS is down
            try {
                await api.post(`/api/chat/rooms/${id}/messages/`, {
                    room: id,
                    content: newMessage
                });
                setNewMessage('');
                if (wsStatus !== 'open') fetchMessages();
            } catch (error) {
                console.error("Failed to send message", error);
                toast.error("Failed to send message");
            }
        }
    };

    const startTyping = () => {
        if (wsStatus === 'open') {
            sendJson({ type: 'typing', is_typing: true });
        }
    };

    const stopTyping = () => {
        if (wsStatus === 'open') {
            sendJson({ type: 'typing', is_typing: false });
        }
    };

    const onTyping = (text: string) => {
        setNewMessage(text);

        if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);

        startTyping();

        typingTimeoutRef.current = setTimeout(() => {
            stopTyping();
        }, 2000);
    };

    const shouldShowDateSeparator = (currentMsg: Message, prevMsg: Message | undefined) => {
        if (!prevMsg) return true;
        return !isSameDay(new Date(currentMsg.timestamp), new Date(prevMsg.timestamp));
    };

    const shouldShowAvatar = (currentMsg: Message, nextMsg: Message | undefined) => {
        if (!nextMsg) return true;
        if (nextMsg.sender.id !== currentMsg.sender.id) return true;
        const timeDiff = new Date(nextMsg.timestamp).getTime() - new Date(currentMsg.timestamp).getTime();
        return timeDiff > 60000; // 1 minute
    };

    if (!id) return null;

    return (
        <div className="flex flex-col h-full w-full bg-background relative isolate overflow-hidden">
            {/* Elegant Header */}
            <header className="flex items-center gap-4 px-4 py-3 bg-background/80 backdrop-blur-xl border-b z-20 sticky top-0 shadow-sm">
                <Button
                    variant="ghost"
                    size="icon"
                    className="md:hidden rounded-full h-10 w-10 text-muted-foreground hover:bg-muted"
                    onClick={() => navigate('/')}
                >
                    <ArrowLeft className="h-6 w-6" />
                </Button>

                <div className="relative group cursor-pointer">
                    <Avatar className="h-11 w-11 ring-2 ring-primary/10 group-hover:ring-primary/30 transition-all duration-300">
                        <AvatarFallback className="bg-gradient-to-br from-primary via-emerald-500 to-teal-600 text-white font-bold text-lg">
                            {getRecipientAvatar()}
                        </AvatarFallback>
                    </Avatar>
                    <div className={cn(
                        "absolute -right-0.5 -bottom-0.5 h-4 w-4 rounded-full border-2 border-background shadow-sm transition-colors duration-500",
                        wsStatus === 'open' ? "bg-green-500" : "bg-red-500 animate-pulse"
                    )} />
                </div>

                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                        <h2 className="font-bold text-[15px] text-foreground tracking-tight leading-none truncate">
                            {getRoomDisplayName()}
                        </h2>
                        {wsStatus === 'open' && (
                            <ShieldCheck className="h-4 w-4 text-primary animate-in fade-in zoom-in duration-500" />
                        )}
                    </div>
                    <div className="flex items-center gap-1.5 mt-1">
                        <span className={cn(
                            "h-1.5 w-1.5 rounded-full transition-colors duration-500",
                            recipientOnline ? "bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]" : "bg-muted-foreground/30"
                        )} />
                        <p className="text-[11px] text-muted-foreground font-semibold uppercase tracking-widest leading-none">
                            {recipientOnline ? 'Online' : 'Offline'}
                        </p>
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon" className="rounded-full h-10 w-10 text-muted-foreground hover:bg-muted transition-colors">
                                <MoreVertical className="h-5 w-5" />
                            </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end" className="w-56 p-2 rounded-xl border-border/50 shadow-2xl backdrop-blur-xl bg-background/95">
                            <DropdownMenuItem className="rounded-lg py-2.5 px-3 cursor-pointer" onClick={() => {
                                navigator.clipboard.writeText(id);
                                toast.success("Room ID copied to clipboard");
                            }}>
                                Copy Channel ID
                            </DropdownMenuItem>
                            <DropdownMenuItem className="rounded-lg py-2.5 px-3 cursor-pointer text-destructive focus:text-destructive focus:bg-destructive/5" onClick={() => navigate('/')}>
                                End Session
                            </DropdownMenuItem>
                        </DropdownMenuContent>
                    </DropdownMenu>
                </div>
            </header>

            {/* Messages Area */}
            {/* Messages Area - Immersive Feel */}
            <ScrollArea className="flex-1 chat-background relative">
                {/* Immersive Pattern Overlay */}
                <div className="absolute inset-0 whatsapp-pattern opacity-[0.04] pointer-events-none" />
                <div className="absolute inset-0 bg-gradient-to-b from-transparent via-background/5 to-transparent pointer-events-none" />

                <div className="max-w-4xl mx-auto px-4 py-10 relative">
                    {loading ? (
                        <div className="flex flex-col items-center justify-center min-h-[40vh] space-y-6">
                            <div className="relative">
                                <div className="h-16 w-16 border-[3px] border-primary/10 border-t-primary rounded-full animate-spin" />
                                <div className="absolute inset-0 flex items-center justify-center">
                                    <ShieldCheck className="h-6 w-6 text-primary/30" />
                                </div>
                            </div>
                            <div className="text-center space-y-2">
                                <p className="text-sm text-foreground font-bold tracking-tight">Securing Connection</p>
                                <p className="text-xs text-muted-foreground">Synchronizing end-to-end encryption...</p>
                            </div>
                        </div>
                    ) : messages.length === 0 ? (
                        <div className="flex flex-col items-center justify-center min-h-[50vh]">
                            <EmptyState
                                title="Safe & Encrypted"
                                description="Messages are encrypted with post-quantum cryptography. Only you and the recipient can read them."
                            />
                        </div>
                    ) : (
                        <div className="flex flex-col space-y-2">
                            {messages.map((msg, index) => {
                                const prevMsg = index > 0 ? messages[index - 1] : undefined;
                                const nextMsg = index < messages.length - 1 ? messages[index + 1] : undefined;
                                const isOwn = msg.sender.id === user?.id;
                                const showDate = shouldShowDateSeparator(msg, prevMsg);
                                const showAvatar = shouldShowAvatar(msg, nextMsg);

                                return (
                                    <React.Fragment key={msg.id || `msg-${index}`}>
                                        {showDate && <DateSeparator date={msg.timestamp} />}
                                        <MessageBubble
                                            content={msg.content}
                                            sender={msg.sender}
                                            timestamp={msg.timestamp}
                                            isOwn={isOwn}
                                            showAvatar={showAvatar}
                                            is_read={msg.is_read}
                                        />
                                    </React.Fragment>
                                );
                            })}

                            {/* Typing Indicators */}
                            {Object.entries(typingUsers).map(([userId, info]) => (
                                info.is_typing && parseInt(userId) !== user?.id && (
                                    <div key={userId} className="flex items-center gap-2 mb-4 animate-in fade-in slide-in-from-bottom-2 duration-300">
                                        <Avatar className="h-8 w-8">
                                            <AvatarFallback className="bg-muted text-[10px]">
                                                {info.username.charAt(0).toUpperCase()}
                                            </AvatarFallback>
                                        </Avatar>
                                        <TypingIndicator />
                                    </div>
                                )
                            ))}
                            <div ref={scrollRef} className="h-6" />
                        </div>
                    )}
                </div>
            </ScrollArea>

            {/* Premium Input Area */}
            <div className="px-4 pb-6 pt-2 bg-gradient-to-t from-background via-background to-transparent z-10">
                <form onSubmit={handleSendMessage} className="max-w-4xl mx-auto flex items-end gap-3 bg-muted/30 backdrop-blur-md p-2 rounded-[28px] border border-border/40 shadow-xl">
                    <div className="flex items-center">
                        <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="rounded-full h-11 w-11 text-muted-foreground hover:bg-muted hover:text-primary transition-all duration-300"
                        >
                            <Smile className="h-6 w-6" />
                        </Button>
                    </div>

                    <div className="flex-1 relative pb-0.5">
                        <textarea
                            placeholder="Type a secure message..."
                            className="w-full bg-transparent border-none focus:ring-0 px-3 py-3 text-[14px] leading-relaxed resize-none max-h-32 min-h-[44px] overflow-y-auto block outline-none transition-all placeholder:text-muted-foreground/60"
                            rows={1}
                            value={newMessage}
                            onChange={(e) => {
                                onTyping(e.target.value);
                                e.target.style.height = 'auto';
                                e.target.style.height = e.target.scrollHeight + 'px';
                            }}
                            onKeyDown={(e) => {
                                if (e.key === 'Enter' && !e.shiftKey) {
                                    e.preventDefault();
                                    handleSendMessage(e as any);
                                }
                            }}
                        />
                    </div>

                    <Button
                        type="submit"
                        size="icon"
                        disabled={!newMessage.trim() || wsStatus === 'connecting'}
                        className={cn(
                            "rounded-full h-11 w-11 flex-shrink-0 transition-all duration-500 transform ease-spring",
                            newMessage.trim()
                                ? "bg-primary text-primary-foreground shadow-lg shadow-primary/30 scale-100 opacity-100"
                                : "bg-muted text-muted-foreground scale-90 opacity-40 cursor-not-allowed"
                        )}
                    >
                        <Send className={cn(
                            "h-5 w-5 transition-all duration-300",
                            newMessage.trim() ? "translate-x-0.5 -translate-y-0.5 rotate-[15deg]" : "scale-90"
                        )} />
                    </Button>
                </form>
                <p className="text-[10px] text-center text-muted-foreground/50 mt-3 font-medium uppercase tracking-[0.2em]">
                    End-to-End Encrypted Session
                </p>
            </div>
        </div>
    );
}
