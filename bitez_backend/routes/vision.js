const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { validateAndEnrich } = require('../models/FoodCatalog');

/**
 * POST /api/vision/detect
 * Hybrid Cloud Vision / Gemini endpoint for multi-item food image recognition.
 * Phase 3: Gemini Vision Image Analysis
 * Phase 4: Food Catalog Validation & Filtering
 */
router.post('/detect', authMiddleware, async (req, res, next) => {
  try {
    const { imageBase64, yoloDetections } = req.body;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'imageBase64 string is required.',
      });
    }

    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');
    let rawDetectedItems = [];

    // Combine local YOLO hint if provided
    let yoloHint = '';
    if (Array.isArray(yoloDetections) && yoloDetections.length > 0) {
      yoloHint = ` Local object detector also saw: ${yoloDetections.map(y => y.label || y).join(', ')}.`;
    }

    // Phase 3: Gemini Vision Cloud Analysis
    const geminiKey = process.env.GEMINI_API_KEY;
    let geminiSuccess = false;

    if (geminiKey) {
      const candidateModels = [
        'gemini-flash-lite-latest',
        'gemini-flash-latest',
        'gemini-3.1-flash-lite',
        'gemini-3-flash-preview',
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash'
      ];
      const promptText = `Analyze this image and identify ALL visible edible food items, raw ingredients, fruits, vegetables, dairy, eggs, meats, seafood, beverages, bakery items, or prepared dishes.${yoloHint}
Strictly ignore plates, bowls, utensils, cutlery, tables, chairs, electronics, bottles, packaging, people, furniture, and non-edible objects.
Return ONLY a raw JSON array of strings e.g. ["Milk", "Egg", "Apple", "Chicken", "Tomato"]. If no food items are visible, return []. Do not use markdown backticks or extra text.`;

      for (const modelName of candidateModels) {
        try {
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${geminiKey}`;
          const response = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [
                {
                  parts: [
                    { text: promptText },
                    {
                      inline_data: {
                        mime_type: 'image/jpeg',
                        data: cleanBase64
                      }
                    }
                  ]
                }
              ]
            }),
          });

          if (response.ok) {
            const data = await response.json();
            const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
            if (candidateText) {
              const match = candidateText.match(/\[\s*[\s\S]*?\s*\]/);
              if (match) {
                try {
                  const parsed = JSON.parse(match[0]);
                  if (Array.isArray(parsed) && parsed.length > 0) {
                    rawDetectedItems = parsed.map((i) => i.toString().trim());
                  }
                } catch (_) {}
              }
            }
            geminiSuccess = true;
            break; // Stop loop on first successful call
          } else {
            console.warn(`Gemini model ${modelName} returned status ${response.status}`);
          }
        } catch (err) {
          console.error(`Gemini vision call error (${modelName}):`, err.message);
        }
      }
    }

    // Fallback to YOLO detections if Gemini did not return items
    if (rawDetectedItems.length === 0) {
      if (Array.isArray(yoloDetections) && yoloDetections.length > 0) {
        rawDetectedItems = yoloDetections.map(d => typeof d === 'string' ? d : d.label);
      }
    }

    // Phase 4: Food Catalog Validation & Filtering
    // Filter out non-food objects and enrich with emoji, category, and defaultSection
    const validatedItems = [];
    const seenNames = new Set();

    for (const rawName of rawDetectedItems) {
      const enriched = validateAndEnrich(rawName);
      if (enriched && !seenNames.has(enriched.name.toLowerCase())) {
        seenNames.add(enriched.name.toLowerCase());
        validatedItems.push({
          label: enriched.name,
          category: enriched.category,
          section: enriched.defaultSection,
          emoji: enriched.emoji,
          isValidated: enriched.isValidated,
        });
      }
    }

    return res.json({
      success: true,
      data: {
        detectedItems: validatedItems.map(item => item.label),
        validatedFoods: validatedItems,
        count: validatedItems.length,
        timestamp: new Date().toISOString(),
      },
    });

  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/vision/expiry-ocr
 * Analyzes a cropped photo of a food item's expiry date label / packaging area.
 * Extracts manufacturing date (MFG), expiration date (EXP / Best Before), and item label.
 */
router.post('/expiry-ocr', authMiddleware, async (req, res, next) => {
  try {
    const { imageBase64 } = req.body;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'imageBase64 string is required.',
      });
    }

    const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');

    const geminiKey = process.env.GEMINI_API_KEY;
    let ocrResult = {
      expiryDate: null,
      manufacturingDate: null,
      itemLabel: null,
      rawText: '',
      notes: '',
    };

    if (geminiKey) {
      const candidateModels = [
        'gemini-flash-lite-latest',
        'gemini-flash-latest',
        'gemini-3.1-flash-lite',
        'gemini-3-flash-preview',
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash'
      ];
      const promptText = `Analyze this close-up image of food packaging / expiry date area.
Carefully look for text indicating Expiry Date (EXP, Expiration, Use By, Best Before, BB, BB/MA) and Manufacturing Date (MFG, MFD, Packed Date, Date of Mfg).
Also identify any product name / food label if visible.

Return ONLY a JSON object formatted exactly as:
{
  "expiryDate": "YYYY-MM-DD",
  "manufacturingDate": "YYYY-MM-DD",
  "itemLabel": "Item Name or null",
  "rawText": "Exact text found e.g. EXP 25/08/2026",
  "notes": "Short helpful note e.g. Best before 14 days after mfg"
}
Note: If year is 2 digits (e.g. 26), convert to 2026. If month is given as name (e.g., AUG), convert to MM (08). If a date field is not found, set its value to null. Return ONLY raw JSON without markdown codeblock formatting.`;

      for (const modelName of candidateModels) {
        try {
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${geminiKey}`;
          const response = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [
                {
                  parts: [
                    { text: promptText },
                    {
                      inline_data: {
                        mime_type: 'image/jpeg',
                        data: cleanBase64
                      }
                    }
                  ]
                }
              ]
            }),
          });

          if (response.ok) {
            const data = await response.json();
            const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
            if (candidateText) {
              const jsonMatch = candidateText.match(/\{[\s\S]*\}/);
              if (jsonMatch) {
                try {
                  const parsed = JSON.parse(jsonMatch[0]);
                  // Inline normalizer used here before the helper below is hoisted
                  const toISO = (raw) => {
                    if (!raw || raw === 'null') return null;
                    raw = String(raw).trim();
                    if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
                    const mn = { jan:'01',feb:'02',mar:'03',apr:'04',may:'05',jun:'06',jul:'07',aug:'08',sep:'09',oct:'10',nov:'11',dec:'12' };
                    let m;
                    // DD/MM/YYYY
                    m = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
                    if (m) return `${m[3]}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;
                    // MM/YYYY
                    m = raw.match(/^(\d{1,2})[\/\-](\d{4})$/);
                    if (m) { const d = new Date(parseInt(m[2]),parseInt(m[1]),0); return `${m[2]}-${m[1].padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; }
                    // MMM YYYY
                    m = raw.match(/^([A-Za-z]{3})\s+(\d{4})$/);
                    if (m && mn[m[1].toLowerCase()]) { const mo=mn[m[1].toLowerCase()]; const d=new Date(parseInt(m[2]),parseInt(mo),0); return `${m[2]}-${mo}-${String(d.getDate()).padStart(2,'0')}`; }
                    // MMM YY
                    m = raw.match(/^([A-Za-z]{3})\s+(\d{2})$/);
                    if (m && mn[m[1].toLowerCase()]) { const mo=mn[m[1].toLowerCase()]; const yr=2000+parseInt(m[2]); const d=new Date(yr,parseInt(mo),0); return `${yr}-${mo}-${String(d.getDate()).padStart(2,'0')}`; }
                    // DD MMM YYYY
                    m = raw.match(/^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$/);
                    if (m && mn[m[2].toLowerCase()]) return `${m[3]}-${mn[m[2].toLowerCase()]}-${m[1].padStart(2,'0')}`;
                    // DD MMM YY
                    m = raw.match(/^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2})$/);
                    if (m && mn[m[2].toLowerCase()]) return `${2000+parseInt(m[3])}-${mn[m[2].toLowerCase()]}-${m[1].padStart(2,'0')}`;
                    const d = new Date(raw);
                    if (!isNaN(d.getTime())) return d.toISOString().split('T')[0];
                    return null;
                  };
                  ocrResult = {
                    expiryDate: toISO(parsed.expiryDate),
                    manufacturingDate: toISO(parsed.manufacturingDate),
                    itemLabel: parsed.itemLabel || null,
                    rawText: parsed.rawText || candidateText,
                    notes: parsed.notes || '',
                  };
                  break;
                } catch (_) {}
              }
            }
          }
        } catch (err) {
          console.error(`Gemini OCR error (${modelName}):`, err.message);
        }
      }
    }

    const monthNames = {
      jan: '01', feb: '02', mar: '03', apr: '04', may: '05', jun: '06',
      jul: '07', aug: '08', sep: '09', oct: '10', nov: '11', dec: '12',
    };

    /**
     * Attempts to turn whatever Gemini returns (e.g. "JUL 2025", "07/2025",
     * "25/08/2026", "AUG 26", "2026-08-25") into a YYYY-MM-DD string.
     * Returns null if it truly cannot parse.
     */
    function normalizeDate(raw) {
      if (!raw || raw === 'null' || raw === 'None') return null;
      raw = String(raw).trim();

      // Already ISO: YYYY-MM-DD
      if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;

      // DD/MM/YYYY or DD-MM-YYYY
      let m = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
      if (m) return `${m[3]}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`;

      // MM/YYYY or MM-YYYY (month only – use last day of that month)
      m = raw.match(/^(\d{1,2})[\/\-](\d{4})$/);
      if (m) {
        const yr = parseInt(m[2], 10);
        const mo = parseInt(m[1], 10);
        const lastDay = new Date(yr, mo, 0).getDate();
        return `${yr}-${String(mo).padStart(2,'0')}-${String(lastDay).padStart(2,'0')}`;
      }

      // MMM YYYY (e.g. "JUL 2025", "AUG 2026")
      m = raw.match(/^([A-Za-z]{3})\s+(\d{4})$/);
      if (m) {
        const mo = monthNames[m[1].toLowerCase()];
        if (mo) {
          const yr = parseInt(m[2], 10);
          const lastDay = new Date(yr, parseInt(mo, 10), 0).getDate();
          return `${yr}-${mo}-${String(lastDay).padStart(2,'0')}`;
        }
      }

      // MMM YY (e.g. "JUL 25", "AUG 26") – 2-digit year
      m = raw.match(/^([A-Za-z]{3})\s+(\d{2})$/);
      if (m) {
        const mo = monthNames[m[1].toLowerCase()];
        if (mo) {
          const yr = 2000 + parseInt(m[2], 10);
          const lastDay = new Date(yr, parseInt(mo, 10), 0).getDate();
          return `${yr}-${mo}-${String(lastDay).padStart(2,'0')}`;
        }
      }

      // DD MMM YYYY (e.g. "25 AUG 2026")
      m = raw.match(/^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$/);
      if (m) {
        const mo = monthNames[m[2].toLowerCase()];
        if (mo) return `${m[3]}-${mo}-${m[1].padStart(2,'0')}`;
      }

      // DD MMM YY (e.g. "25 AUG 26")
      m = raw.match(/^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2})$/);
      if (m) {
        const mo = monthNames[m[2].toLowerCase()];
        if (mo) return `${2000 + parseInt(m[3], 10)}-${mo}-${m[1].padStart(2,'0')}`;
      }

      // Try native Date parse as last resort
      const d = new Date(raw);
      if (!isNaN(d.getTime())) {
        return d.toISOString().split('T')[0];
      }

      return null;
    }

    return res.json({
      success: true,
      ocrResult,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;


