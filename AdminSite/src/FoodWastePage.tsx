import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import { ChevronLeft, Search, Calendar, TrendingDown, TrendingUp, Users, Sparkles } from "lucide-react";
import "./users.css";

interface UserWasteData {
  id: string | number;
  name: string;
  handle: string;
  email: string;
  avatar: string;
  department: string;
  totalWeeklyWasteKg: number;
  trend: "down" | "up" | "stable";
  trendPercentage: number;
  dailyWasteKg: {
    Mon: number;
    Tue: number;
    Wed: number;
    Thu: number;
    Fri: number;
    Sat: number;
    Sun: number;
  };
}

interface FoodWasteProps {
  onBack?: () => void;
}

const INITIAL_WASTE_DATA: UserWasteData[] = [
  {
    id: "6a5f3a9fe737a38181e10dbb",
    name: "Bhadra",
    handle: "@user0",
    email: "bhadra@gmail.com",
    avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
    department: "Design",
    totalWeeklyWasteKg: 4,
    trend: "down",
    trendPercentage: 10,
    dailyWasteKg: { Mon: 1, Tue: 0.7, Wed: 1.2, Thu: 0.4, Fri: 0.8, Sat: 0.2, Sun: 0.3 },
  },
];

const getAvatarUrl = (avatar?: string, name?: string) => {
  if (avatar && avatar.trim() !== "") {
    return avatar;
  }
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name || "User")}`;
};

export const FoodWastePage: React.FC<FoodWasteProps> = ({ onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [usersData, setUsersData] = useState<UserWasteData[]>(INITIAL_WASTE_DATA);
  const [selectedUserId, setSelectedUserId] = useState<string | number>(INITIAL_WASTE_DATA[0].id);
  const [searchTerm, setSearchTerm] = useState("");
  const [hoveredDay, setHoveredDay] = useState<string | null>(null);

  // Fetch data from backend API and accurately map fields
  useEffect(() => {
    fetch("http://localhost:5000/api/food-waste") // Update with your actual food waste endpoint if different
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data) && data.length > 0) {
          const mapped = data.map((item: any, index: number) => {
            const weeklyWaste = item.totalWeeklyWasteKg !== undefined 
              ? item.totalWeeklyWasteKg 
              : 4.0;

            return {
              id: item.id || item._id || index,
              name: item.name || "User",
              handle: item.handle || (item.email ? `@${item.email.split('@')[0]}` : `@user${index}`),
              email: item.email || "",
              avatar: item.avatar || "",
              department: item.department || "General",
              totalWeeklyWasteKg: weeklyWaste,
              trend: item.trend || "down",
              trendPercentage: item.trendPercentage || 10,
              dailyWasteKg: item.dailyWasteKg || {
                Mon: 1,
                Tue: 0.7,
                Wed: 1.2,
                Thu: 0.4,
                Fri: 0.8,
                Sat: 0.2,
                Sun: 0.3,
              },
            };
          });
          setUsersData(mapped);
          setSelectedUserId(mapped[0].id);
        }
      })
      .catch((err) => console.error("Error fetching food waste data from backend:", err));
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
          video.play().catch(() => {});
        });
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

        for (let i = 0; i < data.length; i += 4) {
          const r = data[i];
          const g = data[i + 1];
          const b = data[i + 2];
          const brightness = (r + g + b) / 3;

          if (brightness > 30) {
            data[i]     = brightness * 0.56; 
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

  const activeUser = usersData.find((u) => u.id === selectedUserId) || usersData[0];

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      window.history.back();
    }
  };

  const filteredUsers = usersData.filter((u) => {
    const term = searchTerm.toLowerCase().trim();
    return (
      u.name.toLowerCase().includes(term) ||
      u.handle.toLowerCase().includes(term) ||
      u.department.toLowerCase().includes(term) ||
      u.email.toLowerCase().includes(term)
    );
  });

  const days = activeUser?.dailyWasteKg ? (Object.keys(activeUser.dailyWasteKg) as Array<keyof typeof activeUser.dailyWasteKg>) : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const values = activeUser?.dailyWasteKg ? Object.values(activeUser.dailyWasteKg) : [0,0,0,0,0,0,0];
  const maxWaste = Math.max(...values, 2.0);

  // Find day with highest waste for dynamic insight generation
  const highestDayEntry = activeUser?.dailyWasteKg 
    ? Object.entries(activeUser.dailyWasteKg).reduce((max, curr) => curr[1] > max[1] ? curr : max, ["Mon", 0])
    : ["Wed", 1.2];

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
              placeholder="Search user or email..."
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
          {/* Left Panel: Team Members List */}
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
            <div style={{ padding: "1.25rem 1.5rem", borderBottom: "1px solid rgba(255,255,255,0.15)", display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <Users size={18} style={{ color: "rgba(255,255,255,0.7)" }} />
              <span style={{ color: "rgba(255,255,255,0.7)", fontSize: "0.95rem", fontWeight: 600 }}>
                TEAM MEMBERS ({filteredUsers.length})
              </span>
            </div>

            <div style={{ flex: 1, overflowY: "auto", padding: "1rem", display: "flex", flexDirection: "column", gap: "0.8rem" }}>
              {filteredUsers.map((u) => {
                const isSelected = u.id === selectedUserId;
                return (
                  <div
                    key={u.id}
                    onClick={() => setSelectedUserId(u.id)}
                    style={{
                      background: isSelected ? "rgba(143, 196, 106, 0.25)" : "rgba(255, 255, 255, 0.06)",
                      border: isSelected ? "1px solid rgba(143, 196, 106, 0.6)" : "1px solid rgba(255, 255, 255, 0.12)",
                      borderRadius: "16px",
                      padding: "1.1rem 1.25rem",
                      cursor: "pointer",
                      transition: "all 0.2s ease",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem", minWidth: 0, overflow: "hidden" }}>
                      <img
                        src={getAvatarUrl(u.avatar, u.name)}
                        alt={u.name}
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(u.name)}`;
                        }}
                        style={{ width: "42px", height: "42px", borderRadius: "50%", objectFit: "cover", backgroundColor: "rgba(255,255,255,0.2)", flexShrink: 0 }}
                      />
                      <div style={{ minWidth: 0, overflow: "hidden" }}>
                        <h4 style={{ margin: 0, color: "#fff", fontSize: "1rem", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                          {u.name}
                        </h4>
                        <span style={{ color: "rgba(255,255,255,0.5)", fontSize: "0.8rem", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", display: "block" }}>
                          {u.email}
                        </span>
                      </div>
                    </div>
                    <div style={{ textAlign: "right", flexShrink: 0, marginLeft: "0.5rem" }}>
                      <span style={{ color: "#8fc46a", fontSize: "0.95rem", fontWeight: 700 }}>
                        {u.totalWeeklyWasteKg} kg
                      </span>
                      <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.5)" }}>waste</div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Right Panel: Main Dashboard View */}
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
              padding: "2rem",
              gap: "1.5rem",
            }}
          >
            {/* Header info for selected user */}
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                borderBottom: "1px solid rgba(255,255,255,0.15)",
                paddingBottom: "1.25rem",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "1.25rem" }}>
                <img
                  src={getAvatarUrl(activeUser?.avatar, activeUser?.name)}
                  alt={activeUser?.name}
                  onError={(e) => {
                    (e.target as HTMLImageElement).src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(activeUser?.name || "User")}`;
                  }}
                  style={{ width: "64px", height: "64px", borderRadius: "50%", objectFit: "cover", border: "2px solid rgba(143, 196, 106, 0.6)", backgroundColor: "rgba(255,255,255,0.2)" }}
                />
                <div>
                  <h2 className="font-heading" style={{ margin: 0, color: "#fff", fontSize: "1.5rem" }}>
                    {activeUser?.name}
                  </h2>
                  <span style={{ color: "rgba(255,255,255,0.6)", fontSize: "0.95rem" }}>
                    {activeUser?.email}
                  </span>
                </div>
              </div>

              <div style={{ display: "flex", gap: "1rem" }}>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "0.75rem",
                    background: "rgba(255,255,255,0.08)",
                    padding: "0.6rem 1.1rem",
                    borderRadius: "14px",
                    border: "1px solid rgba(255,255,255,0.15)",
                  }}
                >
                  <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.6)" }}>TOTAL WASTE</div>
                  <div style={{ color: "#fff", fontSize: "1rem", fontWeight: 700 }}>
                    {activeUser?.totalWeeklyWasteKg} kg
                  </div>
                </div>

                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "0.5rem",
                    background: "rgba(255,255,255,0.08)",
                    padding: "0.6rem 1.1rem",
                    borderRadius: "14px",
                    border: "1px solid rgba(255,255,255,0.15)",
                  }}
                >
                  <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.6)" }}>WEEKLY TREND</div>
                  <div style={{ color: activeUser?.trend === "down" ? "#8fc46a" : "#ff6464", fontSize: "0.95rem", fontWeight: 700, display: "flex", alignItems: "center", gap: "0.2rem" }}>
                    {activeUser?.trend === "down" ? <TrendingDown size={16} /> : <TrendingUp size={16} />}
                    {activeUser?.trendPercentage}%
                  </div>
                </div>
              </div>
            </div>

            {/* Subtitle & Tracking info */}
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <div>
                <h3 style={{ color: "#fff", margin: 0, fontSize: "1.1rem", fontWeight: 600 }}>Daily Food Wastage Breakdown</h3>
                <span style={{ color: "rgba(255,255,255,0.5)", fontSize: "0.85rem" }}>Measured in kilograms (kg) recorded across cafeterias and tracking stations.</span>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: "0.4rem", color: "rgba(255,255,255,0.6)", fontSize: "0.85rem" }}>
                <Calendar size={16} />
                <span>Current Week</span>
              </div>
            </div>

            {/* Daily Chart Box */}
            <div
              style={{
                background: "rgba(255, 255, 255, 0.05)",
                borderRadius: "20px",
                border: "1px solid rgba(255, 255, 255, 0.1)",
                padding: "1.5rem",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                flex: 1,
                minHeight: "220px",
              }}
            >
              <div
                style={{
                  display: "flex",
                  alignItems: "flex-end",
                  justifyContent: "space-between",
                  height: "180px",
                  paddingTop: "1rem",
                  paddingBottom: "0.5rem",
                  gap: "1rem",
                }}
              >
                {days.map((day, index) => {
                  const val = Number(values[index]) || 0;
                  const heightPercent = Math.max(Math.min((val / maxWaste) * 100, 100), 10);
                  const isHovered = hoveredDay === day;

                  return (
                    <div
                      key={day}
                      onMouseEnter={() => setHoveredDay(day)}
                      onMouseLeave={() => setHoveredDay(null)}
                      style={{
                        flex: 1,
                        height: "100%",
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "center",
                        justifyContent: "flex-end",
                        position: "relative",
                        cursor: "pointer",
                      }}
                    >
                      {isHovered && (
                        <div
                          style={{
                            position: "absolute",
                            top: "-32px",
                            left: "50%",
                            transform: "translateX(-50%)",
                            backgroundColor: "rgba(0,0,0,0.85)",
                            color: "#8fc46a",
                            padding: "4px 8px",
                            borderRadius: "6px",
                            fontSize: "0.75rem",
                            fontWeight: 700,
                            whiteSpace: "nowrap",
                            border: "1px solid rgba(143, 196, 106, 0.4)",
                            zIndex: 10,
                          }}
                        >
                          {val} kg
                        </div>
                      )}

                      <div
                        style={{
                          width: "100%",
                          maxWidth: "42px",
                          height: `${heightPercent}%`,
                          background: isHovered
                            ? "linear-gradient(180deg, #a5e079 0%, #8fc46a 100%)"
                            : "linear-gradient(180deg, rgba(143, 196, 106, 0.7) 0%, rgba(143, 196, 106, 0.3) 100%)",
                          borderRadius: "8px 8px 4px 4px",
                          transition: "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)",
                          boxShadow: isHovered ? "0 0 15px rgba(143, 196, 106, 0.5)" : "none",
                          margin: "0 auto",
                        }}
                      />

                      <span
                        style={{
                          textAlign: "center",
                          marginTop: "0.75rem",
                          fontSize: "0.85rem",
                          color: isHovered ? "#fff" : "rgba(255,255,255,0.6)",
                          fontWeight: isHovered ? 700 : 500,
                        }}
                      >
                        {day}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Waste Insight Footer Card */}
            <div
              style={{
                background: "rgba(143, 196, 106, 0.08)",
                border: "1px solid rgba(143, 196, 106, 0.25)",
                borderRadius: "14px",
                padding: "1rem 1.25rem",
                display: "flex",
                alignItems: "center",
                gap: "0.75rem",
              }}
            >
              <Sparkles size={20} style={{ color: "#8fc46a", flexShrink: 0 }} />
              <span style={{ color: "#fff", fontSize: "0.9rem", lineHeight: 1.4 }}>
                <strong style={{ color: "#8fc46a" }}>Waste Insight:</strong> {activeUser?.name} recorded highest waste on <span style={{ color: "#8fc46a", fontWeight: 700 }}>{highestDayEntry[0]}</span>. Their trend is currently trending {activeUser?.trend === "down" ? "downward (improving reduction!)" : "upward (requires attention)."}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default FoodWastePage;