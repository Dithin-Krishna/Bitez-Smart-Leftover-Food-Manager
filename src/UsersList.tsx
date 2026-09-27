import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import { ChevronLeft, Search, MoreVertical, Loader2, AlertTriangle } from "lucide-react";
import "./users.css";

export interface UserItem {
  _id: string;
  name: string;
  handle: string;
  email: string;
  status: "online" | "offline";
  avatar?: string;
  department?: string;
}

interface UsersListProps {
  onBack?: () => void;
  onSelectUser?: (user: UserItem) => void;
  apiEndpoint?: string;
}

export const UsersList: React.FC<UsersListProps> = ({
  onBack,
  onSelectUser,
  apiEndpoint = "http://localhost:5000/api/users",
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [users, setUsers] = useState<UserItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");

  // Fetch users from MongoDB backend
  useEffect(() => {
    const fetchUsers = async () => {
      try {
        setLoading(true);
        const response = await fetch(apiEndpoint);
        if (!response.ok) {
          throw new Error(`Failed to fetch users: ${response.statusText}`);
        }
        const data = await response.json();
        setUsers(data || []);
      } catch (err: any) {
        console.error("Error fetching users:", err);
        setError(err.message || "Could not load users from database.");
      } finally {
        setLoading(false);
      }
    };

    fetchUsers();
  }, [apiEndpoint]);

  // Live green fluid wave video background effect
  useEffect(() => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;

    const ctx = canvas.getContext("2d", { alpha: false, willReadFrequently: true });
    const src = "https://stream.mux.com/8wrHPCX2dC3msyYU9ObwqNdm00u3ViXvOSHUMRYSEe5Q.m3u8";
    let hls: Hls | null = null;
    let handleId: number;

    const startStreaming = () => {
      if (Hls.isSupported()) {
        hls = new Hls({ liveSyncDurationCount: 2, lowLatencyMode: true, maxBufferLength: 10 });
        hls.loadSource(src);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, () => { video.play().catch(() => {}); });
      } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
        video.src = src;
        video.play().catch(() => {});
      }
    };

    startStreaming();

    const renderFrame = () => {
      if (video.readyState >= 2 && ctx) {
        const renderWidth = 640;
        const renderHeight = 360;

        if (canvas.width !== renderWidth || canvas.height !== renderHeight) {
          canvas.width = renderWidth;
          canvas.height = renderHeight;
        }

        ctx.drawImage(video, 0, 0, renderWidth, renderHeight);
        const frameData = ctx.getImageData(0, 0, renderWidth, renderHeight);
        const data = frameData.data;

        // Apply green color tint filter matching the theme
        for (let i = 0; i < data.length; i += 4) {
          const brightness = (data[i] + data[i + 1] + data[i + 2]) / 3;
          if (brightness > 30) {
            data[i] = brightness * 0.56; 
            data[i + 1] = brightness * 0.77; 
            data[i + 2] = brightness * 0.42; 
          } else {
            data[i] = 0; data[i + 1] = 0; data[i + 2] = 0;
          }
        }
        ctx.putImageData(frameData, 0, 0);
      }

      if ("requestVideoFrameCallback" in video) {
        // @ts-ignore
        handleId = video.requestVideoFrameCallback(renderFrame);
      } else {
        handleId = requestAnimationFrame(renderFrame);
      }
    };

    if ("requestVideoFrameCallback" in video) {
      // @ts-ignore
      handleId = video.requestVideoFrameCallback(renderFrame);
    } else {
      handleId = requestAnimationFrame(renderFrame);
    }

    return () => {
      if (hls) hls.destroy();
      if ("cancelVideoFrameCallback" in video && typeof handleId === "number") {
        // @ts-ignore
        video.cancelVideoFrameCallback(handleId);
      } else {
        cancelAnimationFrame(handleId);
      }
    };
  }, []);

  const handleBack = () => {
    if (onBack) { onBack(); } else { window.history.back(); }
  };

  const filteredUsers = users.filter((u) => {
    const term = searchTerm.toLowerCase().trim();
    return (
      (u.name && u.name.toLowerCase().includes(term)) ||
      (u.email && u.email.toLowerCase().includes(term))
    );
  });

  const getAvatarSrc = (avatarUrl?: string, userName?: string) => {
    if (avatarUrl && avatarUrl.trim() !== "") {
      return avatarUrl;
    }
    return `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(userName || "User")}`;
  };

  return (
    <div style={{ position: "fixed", inset: 0, width: "100vw", height: "100vh", overflow: "hidden", backgroundColor: "#000" }}>
      {/* Background Video & Canvas Stream */}
      <video ref={videoRef} autoPlay loop muted playsInline style={{ display: "none" }} />
      <canvas ref={canvasRef} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block", objectFit: "cover", zIndex: 0 }} />

      {/* Foreground UI Layer */}
      <div style={{ position: "relative", zIndex: 1, width: "100%", height: "100%", boxSizing: "border-box", display: "flex", flexDirection: "column", padding: "2rem 3rem" }}>
        
        {/* Top Header: Dashboard Button & Search Bar */}
        <header style={{ display: "flex", alignItems: "center", justifyContent: "flex-start", width: "100%", marginBottom: "auto", gap: "1.25rem" }}>
          <button
            type="button"
            onClick={handleBack}
            className="liquid-glass-strong dash-btn"
            style={{
              display: "flex", alignItems: "center", gap: "0.5rem", cursor: "pointer",
              padding: "0.65rem 1.4rem", borderRadius: "9999px", border: "1px solid rgba(255, 255, 255, 0.25)",
              background: "rgba(255, 255, 255, 0.12)", backdropFilter: "blur(16px)", color: "#fff", fontSize: "0.95rem", fontWeight: 500,
            }}
          >
            <ChevronLeft size={20} />
            <span>Dashboard</span>
          </button>

          <div
            className="liquid-glass-strong"
            style={{
              display: "flex", alignItems: "center", gap: "0.85rem", background: "rgba(255, 255, 255, 0.12)",
              backdropFilter: "blur(16px)", borderRadius: "9999px", padding: "0.65rem 1.4rem", width: "320px",
              border: "1px solid rgba(255, 255, 255, 0.25)"
            }}
          >
            <Search size={18} style={{ color: "rgba(255,255,255,0.7)" }} />
            <input
              type="text"
              placeholder="Search users or emails..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ background: "transparent", border: "none", outline: "none", color: "#fff", width: "100%", fontSize: "0.95rem" }}
            />
          </div>
        </header>

        {/* Center Container for Larger User Cards */}
        <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", width: "100%", padding: "1rem 0" }}>
          {loading ? (
            <div style={{ display: "flex", justifyContent: "center", alignItems: "center", flexDirection: "column", gap: "1rem" }}>
              <Loader2 className="animate-spin" size={48} style={{ color: "#a3e635" }} />
              <p style={{ color: "rgba(255,255,255,0.7)", fontSize: "1.1rem" }}>Loading system users...</p>
            </div>
          ) : error ? (
            <div style={{ display: "flex", justifyContent: "center", alignItems: "center", flexDirection: "column", gap: "1rem" }}>
              <AlertTriangle size={48} style={{ color: "#f87171" }} />
              <p style={{ color: "#f87171", fontSize: "1.1rem" }}>{error}</p>
            </div>
          ) : (
            <div 
              style={{ 
                display: "grid", 
                gridTemplateColumns: "repeat(auto-fit, minmax(400px, 1fr))", 
                gap: "2.5rem", 
                justifyContent: "center", 
                justifyItems: "center",
                width: "100%", 
                maxWidth: "1400px",
                maxHeight: "65vh",
                overflowY: "auto",
                padding: "1rem"
              }}
            >
              {filteredUsers.map((user) => (
                <div
                  key={user._id}
                  onClick={() => onSelectUser && onSelectUser(user)}
                  className="liquid-glass-strong"
                  style={{
                    background: "rgba(255, 255, 255, 0.1)",
                    backdropFilter: "blur(24px)",
                    borderRadius: "22px",
                    padding: "2rem",
                    border: "1px solid rgba(255, 255, 255, 0.22)",
                    boxShadow: "0 20px 40px rgba(0,0,0,0.3)",
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "space-between",
                    cursor: "pointer",
                    width: "400px",
                    height: "190px",
                    transition: "transform 0.2s ease, border-color 0.2s ease",
                  }}
                >
                  {/* Card Top Row: Avatar, Name, Three Dots Menu */}
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "1.2rem" }}>
                      <img
                        src={getAvatarSrc(user.avatar, user.name)}
                        alt={user.name}
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(user.name)}`;
                        }}
                        style={{
                          width: "64px",
                          height: "64px",
                          borderRadius: "50%",
                          objectFit: "cover",
                          border: "2px solid rgba(255, 255, 255, 0.35)",
                          backgroundColor: "rgba(255, 255, 255, 0.15)"
                        }}
                      />
                      <h3 style={{ margin: 0, color: "#fff", fontSize: "1.5rem", fontWeight: 400, fontFamily: "serif", fontStyle: "italic" }}>
                        {user.name}
                      </h3>
                    </div>

                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); }}
                      style={{ background: "transparent", border: "none", cursor: "pointer", color: "rgba(255,255,255,0.7)", padding: "4px" }}
                    >
                      <MoreVertical size={22} />
                    </button>
                  </div>

                  {/* Card Bottom Row: Email and Online status indicator */}
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingTop: "1.2rem", borderTop: "1px solid rgba(255,255,255,0.08)" }}>
                    <span style={{ color: "rgba(255, 255, 255, 0.8)", fontSize: "1rem", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: "260px" }}>
                      {user.email}
                    </span>

                    <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                      <span style={{ width: "9px", height: "9px", borderRadius: "50%", backgroundColor: user.status === "online" ? "#34d399" : "#94a3b8", display: "inline-block" }} />
                      <span style={{ color: "rgba(255, 255, 255, 0.85)", fontSize: "0.95rem", textTransform: "capitalize" }}>
                        {user.status || "Online"}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Spacer to balance bottom margin */}
        <div style={{ height: "auto" }} />
      </div>
    </div>
  );
};

export default UsersList;