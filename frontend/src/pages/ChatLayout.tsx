import { Outlet, useParams } from 'react-router-dom';
import { Sidebar } from '@/components/chat/Sidebar';
import { EmptyState } from '@/components/chat/EmptyState';
import { MessageSquare } from 'lucide-react';

export default function ChatLayout() {
    const { id } = useParams<{ id: string }>();

    return (
        <div className="flex h-screen w-full bg-background overflow-hidden">
            {/* Sidebar - Hidden on mobile when chat is open */}
            <div className={`${id ? 'hidden md:flex' : 'flex'} flex-shrink-0`}>
                <Sidebar currentRoomId={id} />
            </div>

            {/* Main Chat Area */}
            <main className={`flex-1 flex flex-col h-full overflow-hidden ${!id ? 'hidden md:flex' : 'flex'}`}>
                {id ? (
                    <Outlet />
                ) : (
                    <div className="flex-1 flex items-center justify-center chat-background">
                        <EmptyState
                            icon={<MessageSquare className="h-16 w-16 text-primary/50" />}
                            title="Welcome to SecureChat"
                            description="Select a chat from the sidebar to start messaging, or search for users to begin a new conversation"
                        />
                    </div>
                )}
            </main>
        </div>
    );
}
