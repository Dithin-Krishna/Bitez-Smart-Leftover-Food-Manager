import React, { useState, useRef, useEffect } from "react";
import Hls from "hls.js";
import jsPDF from "jspdf";
import html2canvas from "html2canvas";
import { ChevronLeft, Search, Leaf, Droplet, Wind, Utensils, Globe, TrendingUp, Award, Download, X, Eye } from "lucide-react";
import "./users.css";

interface ImpactCategory {
  id: string;
  title: string;
  value: string;
  unit: string;
  description: string;
  trend: string;
  icon: any;
  breakdown: { label: string; amount: string; percentage: number }[];
}

interface SustainabilityImpactProps {
  onBack?: () => void;
}

const IMPACT_CATEGORIES: ImpactCategory[] = [
  {
    id: "carbon",
    title: "Carbon Offset (GHG)",
    value: "42.8",
    unit: "tons CO₂e",
    description: "Equivalent to removing greenhouse gas emissions from passenger vehicles over a year.",
    trend: "+14% vs last month",
    icon: Wind,
    breakdown: [
      { label: "Methane Avoided (Landfills)", amount: "28.4 tons", percentage: 66 },
      { label: "Logistics & Transport Saved", amount: "9.2 tons", percentage: 22 },
      { label: "Supply Chain Efficiency", amount: "5.2 tons", percentage: 12 },
    ],
  },
  {
    id: "water",
    title: "Water Conservation",
    value: "1.24M",
    unit: "liters",
    description: "Preserved water resources by preventing the agricultural footprint of wasted crops.",
    trend: "+21% vs last month",
    icon: Droplet,
    breakdown: [
      { label: "Produce & Agriculture", amount: "890,000 L", percentage: 72 },
      { label: "Dairy & Perishables", amount: "240,000 L", percentage: 19 },
      { label: "Beverages & Prep Water", amount: "110,000 L", percentage: 9 },
    ],
  },
  {
    id: "meals",
    title: "Meals Equivalent",
    value: "28,600",
    unit: "meals",
    description: "Nutritious surplus meals successfully redirected to community distribution programs.",
    trend: "+18% vs last month",
    icon: Utensils,
    breakdown: [
      { label: "Corporate Canteen Redirection", amount: "14,200 meals", percentage: 50 },
      { label: "Event Surplus Recovery", amount: "8,400 meals", percentage: 29 },
      { label: "Retail Partner Drops", amount: "6,000 meals", percentage: 21 },
    ],
  },
  {
    id: "landfill",
    title: "Landfill Diversion",
    value: "12.5",
    unit: "metric tons",
    description: "Total organic weight completely redirected from decomposing in municipal landfills.",
    trend: "+9% vs last month",
    icon: Leaf,
    breakdown: [
      { label: "Compost & Organic Enrichment", amount: "5.5 tons", percentage: 44 },
      { label: "Direct Animal Feed Programs", amount: "4.2 tons", percentage: 34 },
      { label: "Biogas Conversion", amount: "2.8 tons", percentage: 22 },
    ],
  },
];

export const SustainabilityImpactPage: React.FC<SustainabilityImpactProps> = ({ onBack }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const [selectedCategory, setSelectedCategory] = useState<string>("carbon");
  const [searchTerm, setSearchTerm] = useState("");
  const [showPreviewModal, setShowPreviewModal] = useState(false);
  const [isGeneratingPdf, setIsGeneratingPdf] = useState(false);

  // HLS Video Stream & Canvas Color Processing Effect (#8fc46a lime-green theme)
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

  const handleBack = () => {
    if (onBack) {
      onBack();
    } else {
      window.history.back();
    }
  };

  // Dedicated 2-Page Separate Capture Generation Handler
  const handleConfirmDownload = async () => {
    const page1El = document.getElementById("pdf-page-1");
    const page2El = document.getElementById("pdf-page-2");
    if (!page1El || !page2El) return;

    try {
      setIsGeneratingPdf(true);
      page1El.style.display = "block";
      page2El.style.display = "block";

      const pdf = new jsPDF("p", "mm", "a4");
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = pdf.internal.pageSize.getHeight();

      // Capture and render Page 1
      const canvas1 = await html2canvas(page1El, { scale: 2, useCORS: true, logging: false });
      pdf.addImage(canvas1.toDataURL("image/png"), "PNG", 0, 0, pdfWidth, pdfHeight);

      // Capture and render Page 2 (Bar Graph Summary)
      pdf.addPage();
      const canvas2 = await html2canvas(page2El, { scale: 2, useCORS: true, logging: false });
      pdf.addImage(canvas2.toDataURL("image/png"), "PNG", 0, 0, pdfWidth, pdfHeight);

      pdf.save("Bitez-Sustainability-Audit-Report.pdf");
      setShowPreviewModal(false);
    } catch (error) {
      console.error("Failed to generate PDF:", error);
    } finally {
      setIsGeneratingPdf(false);
      if (page1El) page1El.style.display = "none";
      if (page2El) page2El.style.display = "none";
    }
  };

  const activeImpact = IMPACT_CATEGORIES.find((cat) => cat.id === selectedCategory) || IMPACT_CATEGORIES[0];

  const filteredCategories = IMPACT_CATEGORIES.filter((cat) =>
    cat.title.toLowerCase().includes(searchTerm.toLowerCase().trim()) ||
    cat.description.toLowerCase().includes(searchTerm.toLowerCase().trim())
  );

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
      {/* ================= PAGE 1 PDF TEMPLATE (OFF-SCREEN) ================= */}
      <div 
        id="pdf-page-1"
        style={{ 
          display: "none", 
          background: "#ffffff", 
          color: "#111111", 
          padding: "2rem", 
          boxSizing: "border-box",
          position: "absolute",
          top: "-9999px",
          left: "-9999px",
          width: "794px",
          height: "1123px",
          zIndex: 99999
        }}
      >
        <div style={{ height: "100%", display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
          <div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "2px solid #2e7d32", paddingBottom: "0.5rem", marginBottom: "1rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <div style={{ width: "26px", height: "26px", background: "#2e7d32", borderRadius: "5px", display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontWeight: 700, fontSize: "0.9rem" }}>B</div>
                <span style={{ fontSize: "1rem", fontWeight: 800, color: "#111", letterSpacing: "-0.5px" }}>BITEZ SMART LEFTOVER FOOD MANAGER</span>
              </div>
              <span style={{ fontSize: "0.75rem", color: "#555", background: "#f5f5f5", padding: "0.15rem 0.5rem", borderRadius: "4px", fontWeight: 500 }}>Executive Audit Tier</span>
            </div>

            <div style={{ marginBottom: "1.5rem" }}>
              <div style={{ color: "#2e7d32", fontSize: "0.75rem", fontWeight: 700, textTransform: "uppercase", letterSpacing: "1px", marginBottom: "0.2rem" }}>Sustainability & Redirection Audit</div>
              <h1 style={{ margin: 0, fontSize: "1.6rem", color: "#111", lineHeight: 1.1 }}>Executive Impact Review</h1>
              <p style={{ color: "#555", fontSize: "0.82rem", marginTop: "0.3rem" }}>
                Generated on {new Date().toLocaleDateString()}. Verified consolidated metrics across all foundational food redirection pillars.
              </p>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem" }}>
              {IMPACT_CATEGORIES.map((cat) => (
                <div key={cat.id} style={{ border: "1px solid #e2e8f0", borderRadius: "8px", padding: "0.85rem 1rem", background: "#fcfcfc" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.4rem" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                      <span style={{ fontSize: "0.9rem", fontWeight: 700, color: "#111" }}>{cat.title}</span>
                      <span style={{ fontSize: "0.7rem", color: "#2e7d32", fontWeight: 600, background: "#e8f5e9", padding: "0.1rem 0.4rem", borderRadius: "3px" }}>{cat.trend}</span>
                    </div>
                    <div style={{ fontSize: "1rem", fontWeight: 800, color: "#2e7d32" }}>
                      {cat.value} <span style={{ fontSize: "0.75rem", color: "#444" }}>{cat.unit}</span>
                    </div>
                  </div>
                  <div style={{ fontSize: "0.75rem", color: "#565656" }}>{cat.description}</div>
                </div>
              ))}
            </div>
          </div>

          <div style={{ borderTop: "1px solid #e2e8f0", paddingTop: "0.5rem", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: "0.75rem", color: "#666" }}>
            <div>BITEZ SMART LEFTOVER FOOD MANAGER • Certified Global Footprint Tier</div>
            <div style={{ fontWeight: 700, color: "#111" }}>Page 1 of 2</div>
          </div>
        </div>
      </div>

      {/* ================= PAGE 2 PDF TEMPLATE (BAR GRAPH SUMMARY) ================= */}
      <div 
        id="pdf-page-2"
        style={{ 
          display: "none", 
          background: "#ffffff", 
          color: "#111111", 
          padding: "2rem", 
          boxSizing: "border-box",
          position: "absolute",
          top: "-9999px",
          left: "-9999px",
          width: "794px",
          height: "1123px",
          zIndex: 99999
        }}
      >
        <div style={{ height: "100%", display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
          <div>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "2px solid #2e7d32", paddingBottom: "0.5rem", marginBottom: "1rem" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                <div style={{ width: "26px", height: "26px", background: "#2e7d32", borderRadius: "5px", display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontWeight: 700, fontSize: "0.9rem" }}>B</div>
                <span style={{ fontSize: "1rem", fontWeight: 800, color: "#111", letterSpacing: "-0.5px" }}>BITEZ SMART LEFTOVER FOOD MANAGER</span>
              </div>
              {/* Top right header badge removed */}
              <div></div>
            </div>

            <div style={{ marginBottom: "1rem" }}>
              <h2 style={{ margin: 0, fontSize: "1.4rem", color: "#111" }}>Impact Source Allocation Breakdown</h2>
              <p style={{ color: "#555", fontSize: "0.8rem", marginTop: "0.2rem" }}>
                Detailed comparative distribution and percentage breakdown across all foundational sustainability pillars.
              </p>
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "0.85rem" }}>
              {IMPACT_CATEGORIES.map((cat) => (
                <div key={cat.id} style={{ border: "1px solid #e2e8f0", borderRadius: "8px", padding: "0.75rem 1rem", background: "#fafafa" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.4rem" }}>
                    <span style={{ fontSize: "0.85rem", fontWeight: 700, color: "#111" }}>{cat.title}</span>
                    <span style={{ fontSize: "0.8rem", fontWeight: 700, color: "#2e7d32" }}>Total: {cat.value} {cat.unit}</span>
                  </div>

                  <div style={{ display: "flex", flexDirection: "column", gap: "0.4rem" }}>
                    {cat.breakdown.map((item, idx) => (
                      <div key={idx} style={{ fontSize: "0.72rem" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "0.15rem" }}>
                          <span style={{ color: "#333", fontWeight: 500 }}>{item.label}</span>
                          <span style={{ fontWeight: 700, color: "#2e7d32" }}>{item.amount} ({item.percentage}%)</span>
                        </div>
                        {/* Guaranteed Static PDF Bar Representation */}
                        <div style={{ width: "100%", height: "8px", background: "#e2e8f0", borderRadius: "4px", overflow: "hidden" }}>
                          <div style={{ width: `${item.percentage}%`, height: "100%", background: "#2e7d32", display: "block" }} />
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div style={{ borderTop: "1px solid #e2e8f0", paddingTop: "0.5rem", display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: "0.75rem", color: "#666" }}>
            <div>BITEZ SMART LEFTOVER FOOD MANAGER • Certified Global Footprint Tier</div>
            <div style={{ fontWeight: 700, color: "#111" }}>Page 2 of 2</div>
          </div>
        </div>
      </div>

      {/* PDF PREVIEW MODAL */}
      {showPreviewModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            zIndex: 999999,
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            backdropFilter: "blur(8px)",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            padding: "2rem",
          }}
        >
          <div
            style={{
              background: "#1e1e1e",
              border: "1px solid rgba(255, 255, 255, 0.15)",
              borderRadius: "20px",
              width: "100%",
              maxWidth: "800px",
              maxHeight: "90vh",
              display: "flex",
              flexDirection: "column",
              overflow: "hidden",
              boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.7)",
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                padding: "1.2rem 1.5rem",
                borderBottom: "1px solid rgba(255, 255, 255, 0.1)",
                background: "rgba(255, 255, 255, 0.03)",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: "0.6rem", color: "#fff" }}>
                <Eye size={20} style={{ color: "#8fc46a" }} />
                <span style={{ fontWeight: 600, fontSize: "1.1rem" }}>2-Page PDF Report Preview</span>
              </div>
              <button
                type="button"
                onClick={() => setShowPreviewModal(false)}
                style={{
                  background: "transparent",
                  border: "none",
                  cursor: "pointer",
                  color: "rgba(255, 255, 255, 0.7)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <X size={22} />
              </button>
            </div>

            <div
              style={{
                flex: 1,
                overflowY: "auto",
                padding: "2rem",
                background: "#f8fafc",
                color: "#111",
              }}
            >
              <div style={{ background: "#fff", padding: "1.5rem", borderRadius: "10px", boxShadow: "0 4px 12px rgba(0,0,0,0.08)", maxWidth: "700px", margin: "0 auto", display: "flex", flexDirection: "column", gap: "1.5rem" }}>
                <div>
                  <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "2px solid #2e7d32", paddingBottom: "0.5rem", marginBottom: "0.75rem" }}>
                    <span style={{ fontWeight: 800, fontSize: "0.95rem", color: "#111" }}>BITEZ SMART LEFTOVER FOOD MANAGER</span>
                    <span style={{ fontSize: "0.7rem", background: "#f5f5f5", padding: "0.15rem 0.4rem", borderRadius: "4px" }}>Page 1 Overview</span>
                  </div>
                  <h2 style={{ fontSize: "1.2rem", margin: "0 0 0.3rem 0", color: "#111" }}>Executive Impact Review</h2>
                  <p style={{ fontSize: "0.78rem", color: "#666" }}>Summary of consolidated metrics across foundational sustainability pillars.</p>
                </div>

                <div style={{ borderTop: "2px dashed #cbd5e1", paddingTop: "1.5rem" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", borderBottom: "2px solid #2e7d32", paddingBottom: "0.5rem", marginBottom: "0.75rem" }}>
                    <span style={{ fontWeight: 800, fontSize: "0.95rem", color: "#111" }}>BITEZ SMART LEFTOVER FOOD MANAGER</span>
                  </div>
                  <h2 style={{ fontSize: "1.2rem", margin: "0 0 0.3rem 0", color: "#111" }}>Impact Source Allocation Breakdown</h2>
                  <p style={{ fontSize: "0.78rem", color: "#666", marginBottom: "1rem" }}>Visual distribution graphs for carbon, water, meals, and landfill conversion.</p>
                  
                  <div style={{ background: "#fcfcfc", border: "1px solid #e2e8f0", borderRadius: "6px", padding: "0.75rem" }}>
                    <div style={{ fontSize: "0.8rem", fontWeight: 700, marginBottom: "0.3rem" }}>Carbon Offset (GHG) Breakdown</div>
                    <div style={{ width: "100%", height: "8px", background: "#e2e8f0", borderRadius: "4px", overflow: "hidden" }}>
                      <div style={{ width: "66%", height: "100%", background: "#2e7d32" }} />
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "flex-end",
                gap: "1rem",
                padding: "1.2rem 1.5rem",
                borderTop: "1px solid rgba(255, 255, 255, 0.1)",
                background: "rgba(255, 255, 255, 0.03)",
              }}
            >
              <button
                type="button"
                onClick={() => setShowPreviewModal(false)}
                style={{
                  background: "transparent",
                  border: "1px solid rgba(255, 255, 255, 0.2)",
                  borderRadius: "9999px",
                  padding: "0.6rem 1.25rem",
                  color: "#fff",
                  cursor: "pointer",
                  fontSize: "0.9rem",
                }}
              >
                Cancel
              </button>

              <button
                type="button"
                onClick={handleConfirmDownload}
                disabled={isGeneratingPdf}
                style={{
                  background: "#8fc46a",
                  border: "none",
                  borderRadius: "9999px",
                  padding: "0.6rem 1.5rem",
                  color: "#111",
                  fontWeight: 700,
                  cursor: isGeneratingPdf ? "wait" : "pointer",
                  fontSize: "0.9rem",
                  display: "flex",
                  alignItems: "center",
                  gap: "0.5rem",
                }}
              >
                <Download size={16} />
                <span>{isGeneratingPdf ? "Generating PDF..." : "Confirm & Download 2-Page PDF"}</span>
              </button>
            </div>
          </div>
        </div>
      )}

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
                placeholder="Search impact indicators..."
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
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
            <div
              className="liquid-glass-strong"
              style={{
                display: "flex",
                alignItems: "center",
                gap: "0.6rem",
                background: "rgba(143, 196, 106, 0.2)",
                border: "1px solid rgba(143, 196, 106, 0.4)",
                borderRadius: "9999px",
                padding: "0.75rem 1.5rem",
                color: "#8fc46a",
                fontWeight: 600,
                fontSize: "0.95rem",
              }}
            >
              <Globe size={18} />
              <span>Global Impact Index • Active</span>
            </div>

            <button
              type="button"
              onClick={() => setShowPreviewModal(true)}
              className="liquid-glass-strong dash-btn"
              style={{
                display: "flex",
                alignItems: "center",
                gap: "0.6rem",
                cursor: "pointer",
                padding: "0.75rem 1.5rem",
                borderRadius: "9999px",
                border: "1px solid rgba(143, 196, 106, 0.5)",
                background: "rgba(143, 196, 106, 0.15)",
                backdropFilter: "blur(16px)",
                color: "#fff",
                fontSize: "0.95rem",
                fontWeight: 600,
                transition: "all 0.2s ease",
              }}
            >
              <Download size={18} style={{ color: "#8fc46a" }} />
              <span>Download Report</span>
            </button>
          </div>
        </header>

        <div
          className="app-main-grid"
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
              <Award size={18} style={{ color: "rgba(255,255,255,0.7)" }} />
              <span style={{ color: "rgba(255,255,255,0.7)", fontSize: "0.95rem", fontWeight: 600 }}>
                SUSTAINABILITY PILLARS ({filteredCategories.length})
              </span>
            </div>

            <div style={{ flex: 1, overflowY: "auto", padding: "1rem", display: "flex", flexDirection: "column", gap: "0.8rem" }}>
              {filteredCategories.map((cat) => {
                const isSelected = cat.id === selectedCategory;
                const IconComponent = cat.icon;
                return (
                  <div
                    key={cat.id}
                    onClick={() => setSelectedCategory(cat.id)}
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
                    <div style={{ display: "flex", alignItems: "center", gap: "0.85rem" }}>
                      <div
                        style={{
                          width: "42px",
                          height: "42px",
                          borderRadius: "12px",
                          background: isSelected ? "rgba(143, 196, 106, 0.3)" : "rgba(255, 255, 255, 0.1)",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          color: isSelected ? "#8fc46a" : "#fff",
                        }}
                      >
                        <IconComponent size={22} />
                      </div>
                      <div>
                        <h4 style={{ margin: 0, color: "#fff", fontSize: "1rem", fontWeight: 600 }}>
                          {cat.title}
                        </h4>
                        <span style={{ color: "rgba(255,255,255,0.5)", fontSize: "0.8rem" }}>
                          {cat.trend}
                        </span>
                      </div>
                    </div>
                    <div style={{ textAlign: "right" }}>
                      <span style={{ color: "#8fc46a", fontSize: "0.95rem", fontWeight: 700 }}>
                        {cat.value}
                      </span>
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
                <div
                  style={{
                    width: "64px",
                    height: "64px",
                    borderRadius: "20px",
                    background: "rgba(143, 196, 106, 0.2)",
                    border: "2px solid rgba(143, 196, 106, 0.6)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    color: "#8fc46a",
                  }}
                >
                  <activeImpact.icon size={32} />
                </div>
                <div>
                  <h2 className="font-heading" style={{ margin: 0, color: "#fff", fontSize: "1.8rem" }}>
                    {activeImpact.title}
                  </h2>
                  <p style={{ margin: "0.2rem 0 0 0", color: "rgba(255,255,255,0.6)", fontSize: "0.95rem" }}>
                    {activeImpact.description}
                  </p>
                </div>
              </div>

              <div style={{ display: "flex", gap: "1rem" }}>
                <div
                  style={{
                    background: "rgba(255, 255, 255, 0.08)",
                    border: "1px solid rgba(255, 255, 255, 0.15)",
                    borderRadius: "16px",
                    padding: "0.8rem 1.25rem",
                    textAlign: "center",
                  }}
                >
                  <div style={{ color: "rgba(255,255,255,0.6)", fontSize: "0.75rem", fontWeight: 600 }}>CUMULATIVE IMPACT</div>
                  <div style={{ color: "#fff", fontSize: "1.4rem", fontWeight: 700, marginTop: "0.2rem" }}>
                    {activeImpact.value} <span style={{ fontSize: "0.9rem", color: "#8fc46a" }}>{activeImpact.unit}</span>
                  </div>
                </div>

                <div
                  style={{
                    background: "rgba(255, 255, 255, 0.08)",
                    border: "1px solid rgba(255, 255, 255, 0.15)",
                    borderRadius: "16px",
                    padding: "0.8rem 1.25rem",
                    textAlign: "center",
                  }}
                >
                  <div style={{ color: "rgba(255,255,255,0.6)", fontSize: "0.75rem", fontWeight: 600 }}>MONTHLY VELOCITY</div>
                  <div
                    style={{
                      color: "#8fc46a",
                      fontSize: "1.1rem",
                      fontWeight: 700,
                      marginTop: "0.4rem",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: "0.3rem",
                    }}
                  >
                    <TrendingUp size={18} />
                    <span>{activeImpact.trend}</span>
                  </div>
                </div>
              </div>
            </div>

            <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "space-between", gap: "1.5rem" }}>
              <div>
                <h3 style={{ margin: "0 0 1rem 0", color: "#fff", fontSize: "1.2rem", fontWeight: 600, letterSpacing: '1px' }}>
                  Impact Source Allocation
                </h3>
                
                <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
                  {activeImpact.breakdown.map((item, idx) => (
                    <div
                      key={idx}
                      style={{
                        background: "rgba(255, 255, 255, 0.05)",
                        border: "1px solid rgba(255, 255, 255, 0.1)",
                        borderRadius: "16px",
                        padding: "1.25rem",
                        display: "flex",
                        flexDirection: "column",
                        gap: "0.6rem",
                      }}
                    >
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <span style={{ color: "#fff", fontWeight: 600, fontSize: "1rem" }}>{item.label}</span>
                        <span style={{ color: "#8fc46a", fontWeight: 700, fontSize: "1rem" }}>
                          {item.amount} ({item.percentage}%)
                        </span>
                      </div>

                      <div
                        style={{
                          width: "100%",
                          height: "8px",
                          background: "rgba(255, 255, 255, 0.1)",
                          borderRadius: "4px",
                          overflow: "hidden",
                          marginTop: "0.25rem",
                        }}
                      >
                        <div
                          style={{
                            width: `${item.percentage}%`,
                            height: "100%",
                            background: "#8fc46a",
                            borderRadius: "4px",
                            transition: "width 0.4s ease-in-out",
                          }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
};
export default SustainabilityImpactPage