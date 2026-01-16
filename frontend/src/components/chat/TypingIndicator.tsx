export function TypingIndicator() {
    return (
        <div className="flex gap-2 mb-2">
            <div className="w-8" /> {/* Spacer for avatar alignment */}
            <div className="message-received px-4 py-3 rounded-lg rounded-tl-sm border border-border/50 flex items-center gap-1">
                <div className="typing-dot w-2 h-2 bg-muted-foreground rounded-full"></div>
                <div className="typing-dot w-2 h-2 bg-muted-foreground rounded-full"></div>
                <div className="typing-dot w-2 h-2 bg-muted-foreground rounded-full"></div>
            </div>
        </div>
    );
}
