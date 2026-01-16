import { useState, useMemo } from 'react';
import { useAuth } from '../context/auth';
import { Link } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { MessageSquare, Eye, EyeOff, Loader2, CheckCircle2, XCircle, User, Mail, Lock } from 'lucide-react';
import { toast } from "sonner";

export default function Register() {
    const [email, setEmail] = useState('');
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [passwordConfirm, setPasswordConfirm] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showPasswordConfirm, setShowPasswordConfirm] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const { register } = useAuth();

    // Password strength calculation
    const passwordStrength = useMemo(() => {
        if (!password) return { score: 0, label: '', color: '' };

        let score = 0;
        if (password.length >= 8) score++;
        if (password.length >= 12) score++;
        if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
        if (/\d/.test(password)) score++;
        if (/[^a-zA-Z0-9]/.test(password)) score++;

        if (score <= 2) return { score, label: 'Weak', color: 'destructive' };
        if (score <= 3) return { score, label: 'Fair', color: 'secondary' };
        if (score <= 4) return { score, label: 'Good', color: 'default' };
        return { score, label: 'Strong', color: 'default' };
    }, [password]);

    const passwordsMatch = useMemo(() => {
        if (!passwordConfirm) return null;
        return password === passwordConfirm;
    }, [password, passwordConfirm]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (password !== passwordConfirm) {
            toast.error("Passwords don't match");
            return;
        }

        if (password.length < 8) {
            toast.error("Password must be at least 8 characters long");
            return;
        }

        setIsLoading(true);

        try {
            await register({
                email,
                username: username || undefined,
                password,
                password_confirm: passwordConfirm
            });
            toast.success("Account created successfully!");
        } catch (err: any) {
            console.error(err);
            const errorMessage = err.message || "Registration failed. Please try again.";
            toast.error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-teal-50 via-green-50 to-emerald-50 dark:from-gray-950 dark:via-gray-900 dark:to-gray-900 p-4">
            {/* WhatsApp Pattern Background */}
            <div className="absolute inset-0 whatsapp-pattern opacity-30" />

            <Card className="w-full max-w-md shadow-2xl border-0 relative z-10 bg-card/95 backdrop-blur-sm">
                <CardHeader className="space-y-4 pb-6">
                    {/* Logo */}
                    <div className="flex justify-center">
                        <div className="relative">
                            <div className="absolute inset-0 bg-primary/20 blur-2xl rounded-full" />
                            <div className="relative p-4 bg-gradient-to-br from-primary to-green-600 rounded-3xl shadow-lg">
                                <MessageSquare className="w-12 h-12 text-white" strokeWidth={2.5} />
                            </div>
                        </div>
                    </div>

                    <div className="text-center space-y-2">
                        <CardTitle className="text-3xl font-bold">
                            Create Account
                        </CardTitle>
                        <CardDescription className="text-base">
                            Join SecureChat for encrypted messaging
                        </CardDescription>
                    </div>
                </CardHeader>

                <CardContent>
                    <form onSubmit={handleSubmit} className="space-y-4">
                        {/* Email Field */}
                        <div className="space-y-2">
                            <Label htmlFor="email" className="text-sm font-medium flex items-center gap-2">
                                <Mail className="h-3.5 w-3.5" />
                                Email Address
                            </Label>
                            <Input
                                id="email"
                                type="email"
                                placeholder="your@email.com"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                className="h-11 bg-muted/50 border-border/50 focus:border-primary transition-all"
                                required
                                autoComplete="email"
                                autoFocus
                            />
                        </div>

                        {/* Username Field */}
                        <div className="space-y-2">
                            <Label htmlFor="username" className="text-sm font-medium flex items-center gap-2">
                                <User className="h-3.5 w-3.5" />
                                Username <span className="text-muted-foreground font-normal text-xs">(Optional)</span>
                            </Label>
                            <Input
                                id="username"
                                type="text"
                                placeholder="Choose a username"
                                value={username}
                                onChange={(e) => setUsername(e.target.value)}
                                className="h-11 bg-muted/50 border-border/50 focus:border-primary transition-all"
                                autoComplete="username"
                            />
                            <p className="text-xs text-muted-foreground">
                                Auto-generated from email if not provided
                            </p>
                        </div>

                        {/* Password Field */}
                        <div className="space-y-2">
                            <div className="flex items-center justify-between">
                                <Label htmlFor="password" className="text-sm font-medium flex items-center gap-2">
                                    <Lock className="h-3.5 w-3.5" />
                                    Password
                                </Label>
                                {password && (
                                    <Badge
                                        variant={passwordStrength.color as any}
                                        className="text-xs h-5"
                                    >
                                        {passwordStrength.label}
                                    </Badge>
                                )}
                            </div>
                            <div className="relative">
                                <Input
                                    id="password"
                                    type={showPassword ? "text" : "password"}
                                    placeholder="Create a strong password"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="h-11 pr-10 bg-muted/50 border-border/50 focus:border-primary transition-all"
                                    required
                                    minLength={8}
                                    autoComplete="new-password"
                                />
                                <Button
                                    type="button"
                                    variant="ghost"
                                    size="icon"
                                    className="absolute right-0 top-0 h-11 w-11 hover:bg-transparent"
                                    onClick={() => setShowPassword(!showPassword)}
                                >
                                    {showPassword ? (
                                        <EyeOff className="h-4 w-4 text-muted-foreground" />
                                    ) : (
                                        <Eye className="h-4 w-4 text-muted-foreground" />
                                    )}
                                </Button>
                            </div>
                            <p className="text-xs text-muted-foreground">
                                Use 8+ characters with letters, numbers & symbols
                            </p>
                        </div>

                        {/* Confirm Password Field */}
                        <div className="space-y-2">
                            <div className="flex items-center justify-between">
                                <Label htmlFor="passwordConfirm" className="text-sm font-medium flex items-center gap-2">
                                    <Lock className="h-3.5 w-3.5" />
                                    Confirm Password
                                </Label>
                                {passwordsMatch !== null && (
                                    <div>
                                        {passwordsMatch ? (
                                            <CheckCircle2 className="h-4 w-4 text-green-500" />
                                        ) : (
                                            <XCircle className="h-4 w-4 text-red-500" />
                                        )}
                                    </div>
                                )}
                            </div>
                            <div className="relative">
                                <Input
                                    id="passwordConfirm"
                                    type={showPasswordConfirm ? "text" : "password"}
                                    placeholder="Re-enter your password"
                                    value={passwordConfirm}
                                    onChange={(e) => setPasswordConfirm(e.target.value)}
                                    className="h-11 pr-10 bg-muted/50 border-border/50 focus:border-primary transition-all"
                                    required
                                    minLength={8}
                                    autoComplete="new-password"
                                />
                                <Button
                                    type="button"
                                    variant="ghost"
                                    size="icon"
                                    className="absolute right-0 top-0 h-11 w-11 hover:bg-transparent"
                                    onClick={() => setShowPasswordConfirm(!showPasswordConfirm)}
                                >
                                    {showPasswordConfirm ? (
                                        <EyeOff className="h-4 w-4 text-muted-foreground" />
                                    ) : (
                                        <Eye className="h-4 w-4 text-muted-foreground" />
                                    )}
                                </Button>
                            </div>
                        </div>

                        {/* Submit Button */}
                        <Button
                            type="submit"
                            className="w-full h-11 bg-primary hover:bg-primary/90 text-white font-medium shadow-lg shadow-primary/25 transition-all hover:shadow-xl hover:shadow-primary/30"
                            disabled={isLoading}
                        >
                            {isLoading ? (
                                <>
                                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                    Creating account...
                                </>
                            ) : (
                                'Create Account'
                            )}
                        </Button>
                    </form>
                </CardContent>

                <CardFooter className="flex flex-col gap-4 pb-6">
                    <div className="text-center text-sm text-muted-foreground">
                        Already have an account?{' '}
                        <Link to="/login" className="text-primary hover:underline font-semibold transition-colors">
                            Sign In
                        </Link>
                    </div>
                </CardFooter>
            </Card>

            {/* Footer */}
            <div className="absolute bottom-4 left-0 right-0 text-center text-xs text-muted-foreground">
                <p>End-to-end encrypted messaging</p>
            </div>
        </div>
    );
}
