const https = require("https");

const districtCache = new Map(); // pin -> { district, state }
const geoCache = new Map(); // pin -> { lat, lon }

function normalizePin(pin) {
  const s = (pin ?? "").toString().trim();
  const digits = s.replace(/\s+/g, "");
  if (!/^\d{6}$/.test(digits)) return null;
  return digits;
}

function getJson(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: "GET",
        headers,
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error("Failed to parse JSON response"));
          }
        });
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function lookupDistrictByPin(pin) {
  const p = normalizePin(pin);
  if (!p) return null;
  if (districtCache.has(p)) return districtCache.get(p);

  // India Post API
  const url = `https://api.postalpincode.in/pincode/${p}`;
  const json = await getJson(url, {
    "User-Agent": "SkillApp/1.0 (pincode lookup)",
    Accept: "application/json",
  });

  const first = Array.isArray(json) ? json[0] : null;
  const postOffice = first?.PostOffice?.[0];
  const district = postOffice?.District;
  const state = postOffice?.State;

  if (!district) return null;

  const result = {
    pincode: p,
    district: district.toString(),
    state: state ? state.toString() : undefined,
  };

  districtCache.set(p, result);
  return result;
}

async function geocodePin(pin) {
  const p = normalizePin(pin);
  if (!p) return null;
  if (geoCache.has(p)) return geoCache.get(p);

  // Nominatim (OpenStreetMap). No API key; keep usage minimal.
  const url = `https://nominatim.openstreetmap.org/search?format=json&country=India&postalcode=${encodeURIComponent(
    p
  )}&limit=1`;
  const json = await getJson(url, {
    "User-Agent": "SkillApp/1.0 (distance estimate)",
    Accept: "application/json",
  });

  const first = Array.isArray(json) ? json[0] : null;
  const lat = first?.lat ? Number(first.lat) : null;
  const lon = first?.lon ? Number(first.lon) : null;
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const result = { pincode: p, lat, lon };
  geoCache.set(p, result);
  return result;
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function estimateDistanceKmByPins(pinA, pinB) {
  const a = normalizePin(pinA);
  const b = normalizePin(pinB);
  if (!a || !b) return null;
  if (a === b) return 1.5;

  const [ga, gb] = await Promise.all([geocodePin(a), geocodePin(b)]);
  if (!ga || !gb) return null;

  const km = haversineKm(ga.lat, ga.lon, gb.lat, gb.lon);
  // Round to 1 decimal; keep it as estimate
  return Math.round(km * 10) / 10;
}

function normalizeAddress(address) {
  if (!address || typeof address !== "object") return null;
  const pincode = normalizePin(address.pincode);
  return {
    houseName: address.houseName?.toString(),
    locality: address.locality?.toString(),
    pincode,
    district: address.district?.toString(),
  };
}

async function validateAndEnrichAddress(address) {
  const normalized = normalizeAddress(address);
  if (!normalized || !normalized.pincode) {
    return { ok: false, message: "Invalid PIN code" };
  }

  const meta = await lookupDistrictByPin(normalized.pincode);
  if (!meta) return { ok: false, message: "PIN code not found" };

  const providedDistrict = (normalized.district ?? "").trim();
  if (providedDistrict && providedDistrict.toLowerCase() !== meta.district.toLowerCase()) {
    return { ok: false, message: "District does not match PIN code" };
  }

  return {
    ok: true,
    address: {
      ...normalized,
      district: meta.district,
    },
    meta,
  };
}

module.exports = {
  normalizePin,
  lookupDistrictByPin,
  geocodePin,
  estimateDistanceKmByPins,
  validateAndEnrichAddress,
};

