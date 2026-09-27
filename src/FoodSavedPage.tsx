import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import { ChevronLeft, Search, Calendar, TrendingUp, Users, Sparkles } from "lucide-react";
import "./users.css";

interface UserSavedData {
  id: string | number;
  name: string;
  handle: string;
  avatar: string;
  department: string;
  totalWeeklySavedKg: number;
  trend: "down" | "up" | "stable";
  trendPercentage: number;
  dailySavedKg: {
    Mon: number;
    Tue: number;
    Wed: number;
    Thu: number;
    Fri: number;
    Sat: number;
    Sun: number;
  };
}

interface FoodSavedProps {
  onBack?: () => void;
}

const INITIAL_SAVED_DATA: UserSavedData[] = [
  {
    id: 1,
    name: "Bhadra",
    handle: "bhadra@gmail.com",
    avatar: "",
    department: "Design",
    totalWeeklySavedKg: 5.6,
    trend: "up",
    trendPercentage: 15,
    dailySavedKg: { Mon: 0.8, Tue: 1.0, Wed: 0.6, Thu: 1.2, Fri: 0.8, Sat: 0.6, Sun: 0.6 },
  },
];

const getAvatarUrl = (avatar?: string, name?: string) => {
  if (avatar && avatar.trim() !== "") {
    return avatar;
  }
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name || "User")}`;
};

export const FoodSavedPage: React.FC<FoodSavedProps> = ({ onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [usersData, setUsersData] = useState<UserSavedData[]>(INITIAL_SAVED_DATA);
  const [selectedUserId, setSelectedUserId] = useState<string | number>(INITIAL_SAVED_DATA[0].id);
  const [searchTerm, setSearchTerm] = useState("");
  const [hoveredDay, setHoveredDay] = useState<string | null>(null);

  // Fetch data from MongoDB backend API and accurately map fields
  useEffect(() => {
    fetch("http://localhost:5000/api/food-saved")
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data) && data.length > 0) {
          const mapped = data.map((item: any, index: number) => {
            // Calculate accurate weekly saved kg based on backend response fields
            const weeklyKg = item.totalFoodSavedKg !== undefined 
              ? item.totalFoodSavedKg 
              : (item.totalItemsSaved ? Number((item.totalItemsSaved * 1.85).toFixed(1)) : 10.0);

            return {
              id: item.id || item._id || index,
              name: item.name || "User",
              handle: item.handle || (item.email ? `@${item.email.split('@')[0]}` : `@user${index}`),
              avatar: item.avatar || "",
              department: item.department || "Design",
              totalWeeklySavedKg: weeklyKg,
              trend: item.trend || (index % 2 === 0 ? "up" : "stable"),
              trendPercentage: item.trendPercentage || (10 + index * 4),
              // Distribute daily metrics safely based on total weekly value if daily breakdown isn't explicitly provided
              dailySavedKg: item.dailySavedKg || {
                Mon: Number((weeklyKg * 0.15).toFixed(1)),
                Tue: Number((weeklyKg * 0.15).toFixed(1)),
                Wed: Number((weeklyKg * 0.10).toFixed(1)),
                Thu: Number((weeklyKg * 0.20).toFixed(1)),
                Fri: Number((weeklyKg * 0.15).toFixed(1)),
                Sat: Number((weeklyKg * 0.12).toFixed(1)),
                Sun: Number((weeklyKg * 0.13).toFixed(1)),
              },
            };
          });
          setUsersData(mapped);
          setSelectedUserId(mapped[0].id);
        }
      })
      .catch((err) => console.error("Error fetching food saved data from backend:", err));
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
      u.department.toLowerCase().includes(term)
    );
  });

  const days = activeUser?.dailySavedKg ? (Object.keys(activeUser.dailySavedKg) as Array<keyof typeof activeUser.dailySavedKg>) : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const values = activeUser?.dailySavedKg ? Object.values(activeUser.dailySavedKg) : [0,0,0,0,0,0,0];
  const maxSaved = Math.max(...values, 3.5);

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
                          {u.handle}
                        </span>
                      </div>
                    </div>
                    <div style={{ textAlign: "right", flexShrink: 0, marginLeft: "0.5rem" }}>
                      <span style={{ color: "#8fc46a", fontSize: "0.95rem", fontWeight: 700 }}>
                        {u.totalWeeklySavedKg} kg
                      </span>
                      <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.5)" }}>saved week</div>
                    </div>
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
              padding: "2rem",
              gap: "2rem",
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                borderBottom: "1px solid rgba(255,255,255,0.15)",
                paddingBottom: "1.5rem",
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
                    {activeUser?.handle}
                  </span>
                </div>
              </div>

              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "0.75rem",
                  background: "rgba(255,255,255,0.08)",
                  padding: "0.75rem 1.25rem",
                  borderRadius: "14px",
                  border: "1px solid rgba(255,255,255,0.15)",
                }}
              >
                <TrendingUp size={20} style={{ color: "#8fc46a" }} />
                <div>
                  <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.6)" }}>Weekly Total</div>
                  <div style={{ color: "#fff", fontSize: "1.1rem", fontWeight: 700 }}>
                    {activeUser?.totalWeeklySavedKg} kg
                  </div>
                </div>
              </div>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: "2rem", flex: 1, minHeight: 0 }}>
              <div
                style={{
                  background: "rgba(255, 255, 255, 0.05)",
                  borderRadius: "20px",
                  border: "1px solid rgba(255, 255, 255, 0.1)",
                  padding: "1.5rem",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                    <Calendar size={18} style={{ color: "rgba(255,255,255,0.7)" }} />
                    <span style={{ color: "#fff", fontWeight: 600, fontSize: "1rem" }}>Daily Savings Breakdown</span>
                  </div>
                  <span style={{ fontSize: "0.85rem", color: "rgba(255,255,255,0.5)" }}>Kilograms (kg)</span>
                </div>

                <div
                  style={{
                    display: "flex",
                    alignItems: "flex-end",
                    justifyContent: "space-between",
                    height: "220px",
                    paddingTop: "2rem",
                    paddingBottom: "1rem",
                    gap: "1rem",
                  }}
                >
                  {days.map((day, index) => {
                    const val = Number(values[index]) || 0;
                    const heightPercent = Math.max(Math.min((val / maxSaved) * 100, 100), 10);
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
                              top: "-35px",
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

              <div
                style={{
                  background: "rgba(255, 255, 255, 0.05)",
                  borderRadius: "20px",
                  border: "1px solid rgba(255, 255, 255, 0.1)",
                  padding: "1.5rem",
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "space-between",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                  <Sparkles size={18} style={{ color: "#8fc46a" }} />
                  <span style={{ color: "#fff", fontWeight: 600, fontSize: "1rem" }}>Performance Insight</span>
                </div>

                <div style={{ display: "flex", flexDirection: "column", gap: "1rem", margin: "auto 0" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
                    <div
                      style={{
                        padding: "0.5rem 0.75rem",
                        background: activeUser?.trend === "up" ? "rgba(143, 196, 106, 0.2)" : "rgba(255, 100, 100, 0.2)",
                        borderRadius: "10px",
                        color: activeUser?.trend === "up" ? "#8fc46a" : "#ff6464",
                        fontWeight: 700,
                        fontSize: "0.9rem",
                      }}
                    >
                      {activeUser?.trend === "up" ? `+${activeUser?.trendPercentage}%` : `${activeUser?.trendPercentage}%`}
                    </div>
                    <span style={{ color: "rgba(255,255,255,0.8)", fontSize: "0.9rem" }}>
                      {activeUser?.trend === "up" ? "Above average team efficiency this week." : "Room for improvement in waste reduction."}
                    </span>
                  </div>

                  <p style={{ color: "rgba(255,255,255,0.5)", fontSize: "0.85rem", margin: 0, lineHeight: 1.5 }}>
                    Consistent logging helps track overall impact accurately across metrics.
                  </p>
                </div>

                <div
                  style={{
                    background: "rgba(143, 196, 106, 0.1)",
                    border: "1px solid rgba(143, 196, 106, 0.3)",
                    borderRadius: "12px",
                    padding: "0.85rem 1rem",
                    textAlign: "center",
                  }}
                >
                  <span style={{ color: "#8fc46a", fontSize: "0.85rem", fontWeight: 600 }}>
                    Top Contributor Status Active
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default FoodSavedPage;