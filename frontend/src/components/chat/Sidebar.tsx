import { useState, useEffect } from 'react';
import { api } from '@/api/client';
import { useAuth } from '@/context/auth';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Search, MessageSquare, LogOut, Menu } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';
import { ThemeToggle } from './ThemeToggle';
import { ChatListItem } from './ChatListItem';
import { EmptyState } from './EmptyState';
import { useWebSocket } from '@/hooks/useWebSocket';
import { useCallback } from 'react';

interface User {
    id: number;
    username: string;
    email: string;
    is_online?: boolean;
}

interface Room {
    id: number;
    name: string;
    participants: User[];
    last_message?: {
        content: string;
        timestamp: string;
        sender: User;
    };
    unread_count?: number;
}

interface SidebarProps {
    currentRoomId?: string;
    onNavigate?: () => void;
}

export function Sidebar({ currentRoomId, onNavigate }: SidebarProps) {
    const { user, logout } = useAuth();
    const navigate = useNavigate();
    const [searchQuery, setSearchQuery] = useState('');
    const [searchResults, setSearchResults] = useState<User[]>([]);
    const [recentRooms, setRecentRooms] = useState<Room[]>([]);
    const [searching, setSearching] = useState(false);
    const [loading, setLoading] = useState(true);

    const handleNotification = useCallback((data: any) => {
        if (data.type === 'new_message') {
            setRecentRooms(prev => {
                const roomExists = prev.some(r => r.id === data.room_id);
                if (!roomExists) {
                    fetchRooms(); // Fetch new room if it's missing
                    return prev;
                }

                const updated = prev.map(room => {
                    if (room.id === data.room_id) {
                        return {
                            ...room,
                            last_message: {
                                ...data.message,
                                sender: { username: data.message.sender } as any
                            },
                            unread_count: (room.unread_count || 0) + (currentRoomId === data.room_id.toString() ? 0 : 1)
                        };
                    }
                    return room;
                });
                return [...updated].sort((a, b) => {
                    const timeA = new Date(a.last_message?.timestamp || 0).getTime();
                    const timeB = new Date(b.last_message?.timestamp || 0).getTime();
                    return timeB - timeA;
                });
            });
        } else if (data.type === 'user_presence') {
            setRecentRooms(prev => prev.map(room => ({
                ...room,
                participants: room.participants.map(p =>
                    p.id === data.user_id ? { ...p, is_online: data.is_online } : p
                )
            })));
        } else if (data.type === 'read_receipt') {
            if (data.user_id !== user?.id) return; // Only reset if we are the one who read it
            setRecentRooms(prev => prev.map(room => {
                if (room.id === data.room_id) {
                    return { ...room, unread_count: 0 };
                }
                return room;
            }));
        }
    }, [currentRoomId, user?.id]);

    const { status } = useWebSocket('notifications', handleNotification);

    useEffect(() => {
        fetchRooms();
    }, []);

    useEffect(() => {
        const delayDebounceFn = setTimeout(() => {
            if (searchQuery) {
                performSearch();
            } else {
                setSearchResults([]);
            }
        }, 300);

        return () => clearTimeout(delayDebounceFn);
    }, [searchQuery]);

    const fetchRooms = async () => {
        try {
            const response = await api.get<Room[]>('/api/chat/rooms/');
            setRecentRooms(response.data);
        } catch (error) {
            console.error("Failed to fetch rooms", error);
        } finally {
            setLoading(false);
        }
    };

    const performSearch = async () => {
        setSearching(true);
        try {
            const response = await api.get<User[]>(`/api/users/search/?search=${searchQuery}`);
            setSearchResults(response.data);
        } catch (error) {
            console.error("Search failed", error);
        } finally {
            setSearching(false);
        }
    };

    const startDirectChat = async (otherUserId: number) => {
        try {
            const response = await api.post('/api/chat/dm/', { user_id: otherUserId });
            const room = response.data;
            navigate(`/chat/${room.id}`);
            onNavigate?.();
            fetchRooms();
            setSearchQuery('');
            setSearchResults([]);
        } catch (error) {
            console.error("Failed to start DM", error);
            toast.error("Failed to start chat.");
        }
    };

    const getRoomDisplayName = (room: Room) => {
        if (room.participants.length === 2) {
            const other = room.participants.find(p => p.username !== user?.username);
            return other?.username || room.name;
        }
        return room.name;
    };

    const getLastMessage = (room: Room) => {
        if (!room.last_message) return "Tap to start chatting";
        const sender = room.last_message.sender.id === user?.id ? "You" : room.last_message.sender.username;
        return `${sender}: ${room.last_message.content}`;
    };

    const getTimestamp = (room: Room) => {
        return room.last_message?.timestamp || new Date().toISOString();
    };
    return (
        <div className="w-full md:w-96 border-r bg-background flex flex-col h-full">
            {/* Header */}
            <div className="p-4 bg-primary/5 border-b">
                <div className="flex items-center justify-between mb-4">
                    <h1 className="text-xl font-bold flex items-center gap-2">
                        <MessageSquare className="h-6 w-6 text-primary" />
                        Messages
                    </h1>
                    <div className="flex items-center gap-1">
                        <Sheet>
                            <SheetTrigger asChild>
                                <Button variant="ghost" size="icon" className="rounded-full h-9 w-9">
                                    <Menu className="h-5 w-5" />
                                </Button>
                            </SheetTrigger>
                            <SheetContent>
                                <SheetHeader>
                                    <SheetTitle>Profile & Settings</SheetTitle>
                                </SheetHeader>
                                <div className="py-6 space-y-6">
                                    {/* User Profile */}
                                    <div className="flex items-center gap-4 p-4 bg-muted/50 rounded-lg">
                                        <Avatar className="h-16 w-16">
                                            <AvatarFallback className="bg-gradient-to-br from-primary to-green-600 text-white text-xl font-bold">
                                                {user?.username?.charAt(0).toUpperCase()}
                                            </AvatarFallback>
                                        </Avatar>
                                        <div className="flex-1 min-w-0">
                                            <h3 className="font-semibold truncate">{user?.username}</h3>
                                            <p className="text-sm text-muted-foreground truncate">{user?.email}</p>
                                        </div>
                                    </div>

                                    <Separator />

                                    {/* Settings */}
                                    <div className="space-y-2">
                                        <div className="flex items-center justify-between p-3 hover:bg-muted/50 rounded-lg cursor-pointer transition-colors">
                                            <span className="text-sm font-medium">Theme</span>
                                            <ThemeToggle />
                                        </div>
                                    </div>

                                    <Separator />

                                    {/* Logout */}
                                    <Button
                                        variant="destructive"
                                        className="w-full"
                                        onClick={() => logout()}
                                    >
                                        <LogOut className="h-4 w-4 mr-2" />
                                        Logout
                                    </Button>
                                </div>
                            </SheetContent>
                        </Sheet>
                    </div>
                </div>

                {/* Search */}
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                        placeholder="Search or start new chat"
                        className="pl-10 bg-background border-border/50 h-10 rounded-lg"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
            </div>

            {/* Chat List */}
            <ScrollArea className="flex-1">
                {searchQuery ? (
                    /* Search Results */
                    <div className="p-2">
                        <div className="px-3 py-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                            {searching ? 'Searching...' : 'Search Results'}
                        </div>
                        {searching ? (
                            <div className="space-y-2 p-2">
                                {[1, 2, 3].map(i => (
                                    <div key={i} className="flex items-center gap-3 p-3">
                                        <Skeleton className="h-12 w-12 rounded-full" />
                                        <div className="flex-1 space-y-2">
                                            <Skeleton className="h-4 w-32" />
                                            <Skeleton className="h-3 w-48" />
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : searchResults.length === 0 ? (
                            <div className="p-8 text-center text-sm text-muted-foreground">
                                No users found
                            </div>
                        ) : (
                            searchResults.map(resultUser => (
                                <ChatListItem
                                    key={resultUser.id}
                                    id={resultUser.id}
                                    name={resultUser.username}
                                    lastMessage={resultUser.email}
                                    onClick={() => startDirectChat(resultUser.id)}
                                />
                            ))
                        )}
                    </div>
                ) : (
                    /* Recent Chats */
                    <div>
                        {loading ? (
                            <div className="space-y-2 p-2">
                                {[1, 2, 3, 4, 5].map(i => (
                                    <div key={i} className="flex items-center gap-3 p-3">
                                        <Skeleton className="h-12 w-12 rounded-full" />
                                        <div className="flex-1 space-y-2">
                                            <Skeleton className="h-4 w-32" />
                                            <Skeleton className="h-3 w-48" />
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : recentRooms.length === 0 ? (
                            <EmptyState
                                title="No chats yet"
                                description="Search for users above to start a conversation"
                            />
                        ) : (
                            recentRooms.map(room => {
                                const displayName = getRoomDisplayName(room);
                                const isGroup = room.participants.length > 2;
                                const unread = room.unread_count || 0;

                                // For DMs, show online status of the other person
                                const otherParticipant = !isGroup ? room.participants.find(p => p.id !== user?.id) : null;
                                const isOnline = otherParticipant?.is_online;

                                return (
                                    <ChatListItem
                                        key={room.id}
                                        id={room.id}
                                        name={displayName}
                                        lastMessage={getLastMessage(room)}
                                        timestamp={getTimestamp(room)}
                                        unreadCount={unread}
                                        isActive={currentRoomId === room.id.toString()}
                                        isGroup={isGroup}
                                        isOnline={isOnline}
                                        participantCount={isGroup ? room.participants.length : undefined}
                                        onClick={() => {
                                            navigate(`/chat/${room.id}`);
                                            onNavigate?.();
                                        }}
                                    />
                                );
                            })
                        )}
                    </div>
                )}
            </ScrollArea>
        </div>
    );
}
