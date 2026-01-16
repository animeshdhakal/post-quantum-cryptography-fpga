import { format, isToday, isYesterday, isThisYear } from "date-fns";

interface DateSeparatorProps {
    date: string | Date;
}

export function DateSeparator({ date }: DateSeparatorProps) {
    const dateObj = typeof date === 'string' ? new Date(date) : date;

    const formatDate = () => {
        if (isToday(dateObj)) {
            return 'Today';
        } else if (isYesterday(dateObj)) {
            return 'Yesterday';
        } else if (isThisYear(dateObj)) {
            return format(dateObj, 'MMMM d');
        } else {
            return format(dateObj, 'MMMM d, yyyy');
        }
    };

    return (
        <div className="flex items-center justify-center my-4">
            <div className="bg-secondary/80 backdrop-blur-sm px-3 py-1 rounded-md shadow-sm">
                <span className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
                    {formatDate()}
                </span>
            </div>
        </div>
    );
}
