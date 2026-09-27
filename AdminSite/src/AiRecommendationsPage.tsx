import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import { ChevronLeft, RefreshCw, CheckCircle2, Send } from "lucide-react";
import "./users.css";

type AiRecommendationsPageProps = {
  onBack?: () => void;
};

type Recommendation = {
  id: number;
  title: string;
  category: "Recipe" | "Storage Tip" | "Expiry Alert";
  description: string;
  impact: string;
  time: string;
};

const initialRecommendations: Recommendation[] = [
  {
    id: 1,
    title: "Transform Overripe Bananas into Energy Bread",
    category: "Recipe",
    description: "We detected 15+ logs of surplus bananas nearing expiry. Recommended action: Broadcast banana bread recipe bundle to local users.",
    impact: "Saves ~4.2 kg waste",
    time: "10 mins ago",
  },
  {
    id: 2,
    title: "Leafy Greens Humidity Optimization",
    category: "Storage Tip",
    description: "Advising users to store spinach and lettuce with paper towels to extend freshness by up to 5 days.",
    impact: "Increases shelf-life 2x",
    time: "1 hour ago",
  },
  {
    id: 3,
    title: "Surplus Dairy Batch Alert (Yogurt & Milk)",
    category: "Expiry Alert",
    description: "Local partner store has 8 units of near-expiry dairy. Trigger quick-discount push notifications.",
    impact: "Prevents 6.5 kg loss",
    time: "3 hours ago",
  },
  {
    id: 4,
    title: "Quick Citrus Zest & Freeze Guide",
    category: "Recipe",
    description: "Suggest freezing excess citrus peels for baking zest to minimize peel wastage across community kitchens.",
    impact: "Saves ~1.8 kg waste",
    time: "5 hours ago",
  },
];

export const AiRecommendationsPage: React.FC<AiRecommendationsPageProps> = ({ onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [recommendations, setRecommendations] = useState<Recommendation[]>(initialRecommendations);
  const [filter, setFilter] = useState<string>("All");
  const [isGenerating, setIsGenerating] = useState<boolean>(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // HLS Video Stream & Canvas Color Processing Effect (Tuned with #8fc46a lime tone)
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
            // Weights derived from #8fc46a (RGB: ~143, 196, 106)
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

  const handleGenerateNew = () => {
    setIsGenerating(true);
    setSuccessMessage(null);
    setTimeout(() => {
      const newRec: Recommendation = {
        id: Date.now(),
        title: "Smart Root Vegetable Broth Recipe Bundle",
        category: "Recipe",
        description: "Generated from aggregate vegetable scrap trends across active users this week.",
        impact: "Saves ~3.5 kg waste",
        time: "Just now",
      };
      setRecommendations([newRec, ...recommendations]);
      setIsGenerating(false);
      setSuccessMessage("Successfully generated new AI recommendations!");
      setTimeout(() => setSuccessMessage(null), 4000);
    }, 1200);
  };

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      window.history.back();
    }
  };

  const filteredRecommendations = filter === "All" 
    ? recommendations 
    : recommendations.filter((rec) => rec.category === filter);

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

      {/* LIQUID FLOWING BACKGROUND CANVAS */}
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
        {/* HEADER */}
        <header
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            width: "100%",
            marginBottom: "2rem",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "1.25rem" }}>
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
          </div>

          <button
            type="button"
            onClick={handleGenerateNew}
            disabled={isGenerating}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "0.6rem",
              cursor: "pointer",
              padding: "0.75rem 1.5rem",
              borderRadius: "9999px",
              border: "1px solid rgba(143, 196, 106, 0.6)",
              background: "rgba(143, 196, 106, 0.25)",
              backdropFilter: "blur(16px)",
              color: "#8fc46a",
              fontSize: "1rem",
              fontWeight: 600,
              transition: "all 0.2s ease",
            }}
          >
            <RefreshCw size={18} className={isGenerating ? "animate-spin" : ""} />
            <span>{isGenerating ? "Analyzing Data..." : "Generate Insights"}</span>
          </button>
        </header>

        {/* MAIN BODY CONTAINER (Increased background opacity to 0.16) */}
        <div
          style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            minHeight: 0,
            maxWidth: "1400px",
            margin: "0 auto",
            width: "100%",
          }}
        >
          <div
            className="liquid-glass-strong"
            style={{
              background: "rgba(20, 25, 20, 0.16)",
              backdropFilter: "blur(28px)",
              borderRadius: "24px",
              display: "flex",
              flexDirection: "column",
              overflow: "hidden",
              boxShadow: "0 20px 40px rgba(0,0,0,0.5)",
              padding: "2rem",
              height: "100%",
              boxSizing: "border-box",
              border: "1px solid rgba(255, 255, 255, 0.2)",
            }}
          >
            <div style={{ marginBottom: "1.5rem" }}>
              <h2 className="font-heading" style={{ fontSize: "1.8rem", margin: 0, color: "#fff" }}>
                Smart AI Insights & Actions
              </h2>
              <p style={{ color: "rgba(255, 255, 255, 0.75)", margin: "0.2rem 0 0 0", fontSize: "0.95rem" }}>
                Automated suggestions powered by user consumption and food waste telemetry.
              </p>
            </div>

            {successMessage && (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "0.75rem",
                  background: "rgba(143, 196, 106, 0.2)",
                  border: "1px solid rgba(143, 196, 106, 0.5)",
                  borderRadius: "14px",
                  padding: "1rem 1.25rem",
                  marginBottom: "1.5rem",
                  color: "#8fc46a",
                }}
              >
                <CheckCircle2 size={20} />
                <span>{successMessage}</span>
              </div>
            )}

            {/* FILTER TABS */}
            <div style={{ display: "flex", gap: "8px", marginBottom: "1.5rem", flexWrap: "wrap" }}>
              {["All", "Recipe", "Storage Tip", "Expiry Alert"].map((tab) => (
                <button
                  key={tab}
                  type="button"
                  onClick={() => setFilter(tab)}
                  style={{
                    padding: "0.6rem 1.25rem",
                    borderRadius: "9999px",
                    border: filter === tab ? "1px solid rgba(143, 196, 106, 0.7)" : "1px solid rgba(255, 255, 255, 0.2)",
                    background: filter === tab ? "rgba(143, 196, 106, 0.3)" : "rgba(255, 255, 255, 0.1)",
                    backdropFilter: "blur(12px)",
                    color: filter === tab ? "#bef264" : "rgba(255, 255, 255, 0.85)",
                    cursor: "pointer",
                    fontSize: "0.9rem",
                    fontWeight: 500,
                    transition: "all 0.2s ease",
                  }}
                >
                  {tab}
                </button>
              ))}
            </div>

            {/* LIST OF RECOMMENDATIONS (Increased opacity of recommendation cards) */}
            <div
              style={{
                flex: 1,
                overflowY: "auto",
                display: "flex",
                flexDirection: "column",
                gap: "1rem",
                paddingRight: "0.5rem",
              }}
            >
              {filteredRecommendations.length === 0 ? (
                <p style={{ textAlign: "center", padding: "40px", color: "rgba(255, 255, 255, 0.5)" }}>
                  No recommendations found for this filter.
                </p>
              ) : (
                filteredRecommendations.map((rec) => (
                  <div
                    key={rec.id}
                    style={{
                      background: "rgba(30, 35, 30, 0.35)",
                      border: "1px solid rgba(255, 255, 255, 0.2)",
                      borderRadius: "16px",
                      padding: "1.25rem 1.5rem",
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "flex-start",
                      gap: "1.5rem",
                      backdropFilter: "blur(16px)",
                      transition: "background 0.2s ease",
                    }}
                  >
                    <div style={{ maxWidth: "75%" }}>
                      <div style={{ display: "flex", gap: "10px", alignItems: "center", marginBottom: "8px" }}>
                        <span
                          style={{
                            fontSize: "0.75rem",
                            padding: "0.2rem 0.6rem",
                            borderRadius: "12px",
                            background:
                              rec.category === "Recipe"
                                ? "rgba(1, 87, 155, 0.35)"
                                : rec.category === "Storage Tip"
                                ? "rgba(46, 125, 50, 0.35)"
                                : "rgba(230, 81, 0, 0.35)",
                            color:
                              rec.category === "Recipe"
                                ? "#69h5ff"
                                : rec.category === "Storage Tip"
                                ? "#bef264"
                                : "#ffcc80",
                            fontWeight: 600,
                            border: "1px solid rgba(255, 255, 255, 0.15)",
                          }}
                        >
                          {rec.category}
                        </span>
                        <span style={{ fontSize: "0.8rem", color: "rgba(255, 255, 255, 0.6)" }}>{rec.time}</span>
                      </div>
                      <h3 className="font-heading" style={{ fontSize: "1.25rem", margin: "0 0 6px 0", color: "#fff" }}>
                        {rec.title}
                      </h3>
                      <p style={{ fontSize: "0.95rem", color: "rgba(255, 255, 255, 0.85)", margin: 0, lineHeight: "1.5" }}>
                        {rec.description}
                      </p>
                    </div>

                    <div
                      style={{
                        textAlign: "right",
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "flex-end",
                        gap: "10px",
                        flexShrink: 0,
                      }}
                    >
                      <span
                        style={{
                          fontSize: "0.85rem",
                          fontWeight: 600,
                          color: "#bef264",
                          background: "rgba(143, 196, 106, 0.2)",
                          border: "1px solid rgba(143, 196, 106, 0.4)",
                          padding: "0.25rem 0.75rem",
                          borderRadius: "8px",
                        }}
                      >
                        {rec.impact}
                      </span>
                      <button
                        type="button"
                        style={{
                          display: "flex",
                          alignItems: "center",
                          gap: "0.4rem",
                          padding: "0.5rem 1rem",
                          background: "rgba(143, 196, 106, 0.18)",
                          border: "1px solid rgba(143, 196, 106, 0.5)",
                          color: "#bef264",
                          borderRadius: "8px",
                          cursor: "pointer",
                          fontSize: "0.85rem",
                          fontWeight: 500,
                        }}
                        onClick={() => alert(`Broadcasted "${rec.title}" to active platform users!`)}
                      >
                        <Send size={14} />
                        <span>Broadcast</span>
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AiRecommendationsPage;