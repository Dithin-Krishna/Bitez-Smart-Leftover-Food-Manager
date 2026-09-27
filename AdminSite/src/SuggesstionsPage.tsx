import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import { ChevronLeft, Search, Send } from "lucide-react";
import "./users.css";

interface Message {
  id: number | string;
  sender: "user" | "admin";
  text: string;
  timestamp: string;
}

interface Suggestion {
  id: number | string;
  userName: string;
  userHandle: string;
  userAvatar: string;
  title: string;
  originalText: string;
  category: "Feature" | "Bug" | "General";
  status: "Pending" | "Reviewed" | "Resolved";
  date: string;
  messages: Message[];
}

interface SuggestionsProps {
  onBack?: () => void;
}

const INITIAL_SUGGESTIONS: Suggestion[] = [
  {
    id: 1,
    userName: "Elena Rostova",
    userHandle: "@elena_vinyl",
    userAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=350&q=80",
    title: "Suggestion 1",
    originalText: "Add dark mode toggle for export panels",
    category: "Feature",
    status: "Pending",
    date: "Today, 2:45 PM",
    messages: [
      {
        id: 101,
        sender: "user",
        text: "Add dark mode toggle for export panels",
        timestamp: "2:45 PM",
      },
    ],
  },
];

const getAvatarUrl = (avatar?: string, name?: string) => {
  if (avatar && avatar.trim() !== "") {
    return avatar;
  }
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name || "User")}`;
};

export const SuggestionsPage: React.FC<SuggestionsProps> = ({ onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [suggestions, setSuggestions] = useState<Suggestion[]>(INITIAL_SUGGESTIONS);
  const [selectedSuggestionId, setSelectedSuggestionId] = useState<number | string>(INITIAL_SUGGESTIONS[0].id);
  const [replyText, setReplyText] = useState("");
  const [searchTerm, setSearchTerm] = useState("");

  // Fetch suggestions data from MongoDB backend API on mount
  useEffect(() => {
    fetch("http://localhost:5000/api/suggestions")
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data) && data.length > 0) {
          const mappedSuggestions = data.map((item: any, index: number) => {
            const suggestionText = item.text || item.title || item.suggestionText || "General feedback";
            const suggestionTime = item.time || item.date || "Recently";

            return {
              id: item.id || item._id || index,
              userName: item.userName || item.name || "Anonymous User",
              userHandle: item.userHandle || (item.email ? `@${item.email.split('@')[0]}` : `@user${index}`),
              userAvatar: getAvatarUrl(item.userAvatar || item.avatar, item.userName || item.name),
              title: `Suggestion ${index + 1}`, // Numbered heading title
              originalText: suggestionText,
              category: item.category || "General",
              status: item.status ? item.status.charAt(0).toUpperCase() + item.status.slice(1) : "Pending",
              date: suggestionTime,
              messages: Array.isArray(item.messages) && item.messages.length > 0 
                ? item.messages.map((m: any, mIndex: number) => ({
                    id: m.id || m._id || mIndex,
                    sender: m.sender || "user",
                    text: m.text || "",
                    timestamp: m.timestamp || "Just now",
                  }))
                : [
                    {
                      id: 1,
                      sender: "user",
                      text: suggestionText,
                      timestamp: suggestionTime,
                    },
                  ],
            };
          });
          setSuggestions(mappedSuggestions);
          setSelectedSuggestionId(mappedSuggestions[0].id);
        }
      })
      .catch((err) => console.error("Error fetching suggestions from MongoDB:", err));
  }, []);

  // HLS Video Stream & Canvas Color Processing Effect
  useEffect(() => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    if (!video || !canvas) return;

    const ctx = canvas.getContext("2d", { alpha: false });
    const src = "https://stream.mux.com/8wrHPCX2dC3msyYU9ObwqNdm00u3ViXvOSHUMRYSEe5Q.m3u8";
    let hls: Hls | null = null;
    let handleId: number;

    const startStreaming = () => {
      if (Hls.isSupported()) {
        hls = new Hls({
          liveSyncDurationCount: 2,
          lowLatencyMode: true,
          maxBufferLength: 10,
        });

        hls.loadSource(src);
        hls.attachMedia(video);

        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          video.play().catch(() => { });
        });
      } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
        video.src = src;
        video.play().catch(() => { });
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

        for (let i = 0; i < data.length; i += 4) {
          const r = data[i];
          const g = data[i + 1];
          const b = data[i + 2];
          const brightness = (r + g + b) / 3;

          if (brightness > 30) {
            data[i] = brightness * 0.56;
            data[i + 1] = brightness * 0.77;
            data[i + 2] = brightness * 0.42;
          } else {
            data[i] = 0;
            data[i + 1] = 0;
            data[i + 2] = 0;
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

  const activeSuggestion = suggestions.find((s) => s.id === selectedSuggestionId) || suggestions[0];

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      window.history.back();
    }
  };

  const handleSendReply = (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyText.trim()) return;

    const newMsg: Message = {
      id: Date.now(),
      sender: "admin",
      text: replyText.trim(),
      timestamp: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }),
    };

    // Optimistically update UI state
    setSuggestions((prev) =>
      prev.map((item) =>
        item.id === activeSuggestion.id
          ? { ...item, messages: [...item.messages, newMsg], status: "Reviewed" }
          : item
      )
    );

    // Sync reply back to MongoDB backend API
    fetch(`http://localhost:5000/api/suggestions/${activeSuggestion.id}/messages`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(newMsg),
    }).catch((err) => console.error("Error saving admin reply to MongoDB:", err));

    setReplyText("");
  };

  const filteredSuggestions = suggestions.filter((s) => {
    const term = searchTerm.toLowerCase().trim();
    return (
      s.title.toLowerCase().includes(term) ||
      s.originalText.toLowerCase().includes(term) ||
      s.userName.toLowerCase().includes(term) ||
      s.userHandle.toLowerCase().includes(term)
    );
  });

  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        width: "100vw",
        height: "100vh",
        overflow: "hidden",
        backgroundColor: "#000",
      }}
    >
      <video ref={videoRef} autoPlay loop muted playsInline style={{ display: "none" }} />

      <canvas
        ref={canvasRef}
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          display: "block",
          objectFit: "cover",
          zIndex: 0,
        }}
      />

      <div
        style={{
          position: "relative",
          zIndex: 1,
          width: "100%",
          height: "100%",
          boxSizing: "border-box",
          display: "flex",
          flexDirection: "column",
          padding: "2rem 3rem",
        }}
      >
        <header
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "flex-start",
            width: "100%",
            marginBottom: "2rem",
            gap: "1.25rem",
          }}
        >
          <button
            type="button"
            onClick={handleBack}
            className="liquid-glass-strong dash-btn"
            style={{
              display: "flex",
              alignItems: "center",
              gap: "0.6rem",
              cursor: "pointer",
              padding: "0.75rem 1.5rem",
              borderRadius: "9999px",
              border: "1px solid rgba(255, 255, 255, 0.25)",
              background: "rgba(255, 255, 255, 0.12)",
              backdropFilter: "blur(16px)",
              color: "#fff",
              fontSize: "1rem",
              fontWeight: 500,
            }}
          >
            <ChevronLeft size={22} />
            <span>Dashboard</span>
          </button>

          <div
            className="liquid-glass-strong"
            style={{
              display: "flex",
              alignItems: "center",
              gap: "0.85rem",
              background: "rgba(255, 255, 255, 0.12)",
              backdropFilter: "blur(16px)",
              borderRadius: "9999px",
              padding: "0.75rem 1.5rem",
              width: "340px",
            }}
          >
            <Search size={20} style={{ color: "rgba(255,255,255,0.7)" }} />
            <input
              type="text"
              placeholder="Search feedback..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{
                background: "transparent",
                border: "none",
                outline: "none",
                color: "#fff",
                width: "100%",
                fontSize: "1rem",
              }}
            />
          </div>
        </header>

        <div
          style={{
            flex: 1,
            display: "grid",
            gridTemplateColumns: "380px 1fr",
            gap: "2rem",
            minHeight: 0,
            maxWidth: "1600px",
            margin: "0 auto",
            width: "100%",
          }}
        >
          <div
            className="liquid-glass-strong"
            style={{
              background: "rgba(255, 255, 255, 0.08)",
              backdropFilter: "blur(24px)",
              borderRadius: "24px",
              display: "flex",
              flexDirection: "column",
              overflow: "hidden",
              boxShadow: "0 20px 40px rgba(0,0,0,0.4)",
            }}
          >
            <div style={{ padding: "1.25rem 1.5rem", borderBottom: "1px solid rgba(255,255,255,0.15)" }}>
              <span style={{ color: "rgba(255,255,255,0.7)", fontSize: "0.95rem", fontWeight: 600 }}>
                INBOX ({filteredSuggestions.length})
              </span>
            </div>

            <div style={{ flex: 1, overflowY: "auto", padding: "1rem", display: "flex", flexDirection: "column", gap: "0.8rem" }}>
              {filteredSuggestions.map((s) => {
                const isSelected = s.id === selectedSuggestionId;
                return (
                  <div
                    key={s.id}
                    onClick={() => setSelectedSuggestionId(s.id)}
                    style={{
                      background: isSelected ? "rgba(143, 196, 106, 0.25)" : "rgba(255, 255, 255, 0.06)",
                      border: isSelected ? "1px solid rgba(143, 196, 106, 0.6)" : "1px solid rgba(255, 255, 255, 0.12)",
                      borderRadius: "16px",
                      padding: "1.25rem",
                      cursor: "pointer",
                      transition: "all 0.2s ease",
                      display: "flex",
                      flexDirection: "column",
                      gap: "0.6rem",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
                        <img
                          src={s.userAvatar}
                          alt={s.userName}
                          onError={(e) => {
                            (e.target as HTMLImageElement).src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(s.userName)}`;
                          }}
                          style={{ width: "36px", height: "36px", borderRadius: "50%", objectFit: "cover", backgroundColor: "rgba(255,255,255,0.2)" }}
                        />
                        <div>
                          <h4 style={{ margin: 0, color: "#fff", fontSize: "0.95rem", fontWeight: 600 }}>
                            {s.userName}
                          </h4>
                          <span style={{ color: "rgba(255,255,255,0.5)", fontSize: "0.8rem" }}>
                            {s.userHandle}
                          </span>
                        </div>
                      </div>
                      <span
                        style={{
                          fontSize: "0.75rem",
                          padding: "0.25rem 0.6rem",
                          borderRadius: "99px",
                          background:
                            s.status === "Resolved"
                              ? "rgba(16, 185, 129, 0.2)"
                              : s.status === "Reviewed"
                              ? "rgba(59, 130, 246, 0.2)"
                              : "rgba(234, 179, 8, 0.2)",
                          color:
                            s.status === "Resolved"
                              ? "#34d399"
                              : s.status === "Reviewed"
                              ? "#60a5fa"
                              : "#facc15",
                          fontWeight: 500,
                        }}
                      >
                        {s.status}
                      </span>
                    </div>

                    <p
                      style={{
                        margin: 0,
                        color: "#fff",
                        fontSize: "1rem",
                        fontWeight: 500,
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                    >
                      {s.title}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>

          <div
            className="liquid-glass-strong"
            style={{
              background: "rgba(255, 255, 255, 0.08)",
              backdropFilter: "blur(24px)",
              borderRadius: "24px",
              display: "flex",
              flexDirection: "column",
              overflow: "hidden",
              boxShadow: "0 20px 40px rgba(0,0,0,0.4)",
            }}
          >
            <div
              style={{
                padding: "1.5rem 2rem",
                borderBottom: "1px solid rgba(255,255,255,0.15)",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                background: "rgba(0,0,0,0.15)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
                <img
                  src={activeSuggestion?.userAvatar}
                  alt={activeSuggestion?.userName}
                  onError={(e) => {
                    (e.target as HTMLImageElement).src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(activeSuggestion?.userName || "User")}`;
                  }}
                  style={{ width: "48px", height: "48px", borderRadius: "50%", objectFit: "cover", backgroundColor: "rgba(255,255,255,0.2)" }}
                />
                <div>
                  <h3 className="font-heading" style={{ margin: 0, color: "#fff", fontSize: "1.5rem" }}>
                    {activeSuggestion?.title}
                  </h3>
                  <p style={{ margin: "0.2rem 0 0 0", color: "rgba(255,255,255,0.6)", fontSize: "0.9rem" }}>
                    Submitted by {activeSuggestion?.userName} ({activeSuggestion?.userHandle}) • {activeSuggestion?.date}
                  </p>
                </div>
              </div>

              <span
                style={{
                  background: "rgba(143, 196, 106, 0.2)",
                  color: "#a3e635",
                  border: "1px solid rgba(143, 196, 106, 0.4)",
                  padding: "0.4rem 0.8rem",
                  borderRadius: "12px",
                  fontSize: "0.9rem",
                  fontWeight: 600,
                }}
              >
                {activeSuggestion?.category}
              </span>
            </div>

            <div
              style={{
                flex: 1,
                overflowY: "auto",
                padding: "2rem",
                display: "flex",
                flexDirection: "column",
                gap: "1.25rem",
              }}
            >
              {activeSuggestion?.messages?.map((msg) => {
                const isAdmin = msg.sender === "admin";
                return (
                  <div
                    key={msg.id}
                    style={{
                      display: "flex",
                      flexDirection: "column",
                      alignItems: isAdmin ? "flex-end" : "flex-start",
                      width: "100%",
                    }}
                  >
                    <div
                      style={{
                        maxWidth: "70%",
                        background: isAdmin
                          ? "linear-gradient(135deg, rgba(143, 196, 106, 0.35), rgba(110, 165, 75, 0.35))"
                          : "rgba(255, 255, 255, 0.12)",
                        border: isAdmin
                          ? "1px solid rgba(143, 196, 106, 0.5)"
                          : "1px solid rgba(255, 255, 255, 0.2)",
                        borderRadius: isAdmin ? "20px 20px 4px 20px" : "20px 20px 20px 4px",
                        padding: "1.2rem 1.5rem",
                        color: "#fff",
                        boxShadow: "0 10px 25px rgba(0,0,0,0.2)",
                      }}
                    >
                      <div
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          alignItems: "center",
                          marginBottom: "0.5rem",
                          gap: "2rem",
                        }}
                      >
                        <span
                          style={{
                            fontSize: "0.85rem",
                            fontWeight: 600,
                            color: isAdmin ? "#bef264" : "rgba(255,255,255,0.8)",
                          }}
                        >
                          {isAdmin ? "Admin (You)" : activeSuggestion?.userName}
                        </span>
                        <span style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.5)" }}>
                          {msg.timestamp}
                        </span>
                      </div>
                      <p style={{ margin: 0, fontSize: "1.05rem", lineHeight: 1.5, wordBreak: "break-word" }}>
                        {msg.text}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>

            <form
              onSubmit={handleSendReply}
              style={{
                padding: "1.5rem 2rem",
                borderTop: "1px solid rgba(255,255,255,0.15)",
                background: "rgba(0,0,0,0.2)",
                display: "flex",
                gap: "1rem",
              }}
            >
              <input
                type="text"
                placeholder="Type your reply as admin..."
                value={replyText}
                onChange={(e) => setReplyText(e.target.value)}
                style={{
                  flex: 1,
                  background: "rgba(255, 255, 255, 0.1)",
                  border: "1px solid rgba(255, 255, 255, 0.25)",
                  borderRadius: "14px",
                  padding: "0.9rem 1.25rem",
                  color: "#fff",
                  fontSize: "1.05rem",
                  outline: "none",
                }}
              />
              <button
                type="submit"
                style={{
                  background: "#8fc46a",
                  color: "#0f172a",
                  border: "none",
                  borderRadius: "14px",
                  padding: "0 1.75rem",
                  fontWeight: 700,
                  fontSize: "1.05rem",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.5rem",
                  boxShadow: "0 4px 15px rgba(143, 196, 106, 0.4)",
                }}
              >
                <Send size={18} />
                <span>Send</span>
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SuggestionsPage;