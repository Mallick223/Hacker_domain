// Guardian AI Premium Testing Dashboard Logic

// API Configuration
const API_BASE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? window.location.origin
    : 'https://go-ai-model-production.up.railway.app';

// State management
const state = {
    // Current UI View
    activeTab: 'view-monitor',
    
    // Camera
    cameraStream: null,
    capturedImageBase64: null,
    
    // GPS & Map
    map: null,
    normalRouteLine: null,
    routePoints: [],
    detourMarker: null,
    isDrawingRoute: true,
    gpsParameters: {
        deviation_m: 0.0,
        speed_kmh: 5.5,
        heading_change_rate: 5.0,
        stationary_off_route_min: 0.0,
        time_since_gps_sec: 20.0,
        speed_delta: 0.0
    },
    gpsWatchId: null,
    lastLatLng: null,
    lastGpsTime: null,
    lastSpeed: 5.5,
    
    // Sensors & Activity
    activeActivityClass: 2, // Sitting (default)
    activityConfidence: 0.95,
    
    // Emergency Trigger
    sosPressed: false,
    sosCoverOpen: false,
    
    // Audio / Alerts
    prevAlertsState: {}
};

// ============================================================
// 1. INITIALIZATION & LAYOUT CONFIG
// ============================================================

window.addEventListener('DOMContentLoaded', () => {
    checkBackendHealth();
    initTabs();
    initMap();
    initSensors();
    initSliders();
    initCamera();
    initSosTrigger();
    initLogActions();
    
    // Periodic update every 3 seconds to keep risk score fresh
    setInterval(updatePipeline, 3000);
});

async function checkBackendHealth() {
    const statusEl = document.getElementById('api-status');
    try {
        const res = await fetch(`${API_BASE}/api/health`);
        const data = await res.json();
        if (data.status === 'healthy') {
            statusEl.innerHTML = `<span class="status-dot online"></span> Engine Online (${data.device.toUpperCase()})`;
            statusEl.className = 'status-indicator text-success';
        } else {
            statusEl.innerHTML = `<span class="status-dot pulsing"></span> Loading Models...`;
        }
    } catch (err) {
        statusEl.innerHTML = `<span class="status-dot pulsing"></span> Connection Error`;
        statusEl.className = 'status-indicator text-danger';
        console.error("Backend health check failed:", err);
    }
}

// Sidebar View Toggle routing
function initTabs() {
    const navItems = document.querySelectorAll('.nav-item');
    const tabViews = document.querySelectorAll('.tab-view');
    const viewTitle = document.getElementById('view-title');
    const viewSubtitle = document.getElementById('view-subtitle');

    const headersMap = {
        'view-monitor': {
            title: 'Live Monitor',
            sub: 'Real-time tourist telemetry & predictive risk scoring'
        },
        'view-simulator': {
            title: 'Simulator Deck',
            sub: 'Override telemetry sensors to test XGBoost Risk Fusion rules'
        },
        'view-diagnostics': {
            title: 'Diagnostics & Logs',
            sub: 'Live JSON payloads and feature explainability reports'
        }
    };

    navItems.forEach(item => {
        item.addEventListener('click', () => {
            const targetTab = item.getAttribute('data-tab');
            state.activeTab = targetTab;

            // Nav active states
            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            // View block visibility
            tabViews.forEach(view => view.classList.remove('active'));
            document.getElementById(targetTab).classList.add('active');

            // Header titles
            if (headersMap[targetTab]) {
                viewTitle.textContent = headersMap[targetTab].title;
                viewSubtitle.textContent = headersMap[targetTab].sub;
            }

            // Force leaflet map container resize upon viewing
            if (targetTab === 'view-monitor' && state.map) {
                setTimeout(() => state.map.invalidateSize(), 150);
            }
        });
    });
}

// ============================================================
// 2. SLIDERS & TELEMETRY ADJUSTMENTS
// ============================================================

function initSliders() {
    const hrSlider = document.getElementById('slide-hr');
    const hrVal = document.getElementById('val-hr');
    hrSlider.addEventListener('input', (e) => {
        hrVal.textContent = `${e.target.value} BPM`;
        triggerImmediateUpdate();
    });

    const crimeSlider = document.getElementById('slide-crime');
    const crimeVal = document.getElementById('val-crime');
    crimeSlider.addEventListener('input', (e) => {
        crimeVal.textContent = `${e.target.value}%`;
        triggerImmediateUpdate();
    });

    const crowdSlider = document.getElementById('slide-crowd');
    const crowdVal = document.getElementById('val-crowd');
    crowdSlider.addEventListener('input', (e) => {
        crowdVal.textContent = `${parseFloat(e.target.value).toFixed(2)} p/m²`;
        triggerImmediateUpdate();
    });

    document.getElementById('select-weather').addEventListener('change', triggerImmediateUpdate);
    document.getElementById('select-geofence').addEventListener('change', triggerImmediateUpdate);
    document.getElementById('select-hour').addEventListener('change', triggerImmediateUpdate);

    // Wire up Slider Increment/Decrement Button Controls
    const adjustBtns = document.querySelectorAll('.btn-adjust');
    adjustBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const controlId = btn.getAttribute('data-control');
            const delta = parseFloat(btn.getAttribute('data-delta'));
            const slider = document.getElementById(controlId);
            
            if (slider) {
                let newVal = parseFloat(slider.value) + delta;
                // Clamp value to slider constraints
                const min = parseFloat(slider.min);
                const max = parseFloat(slider.max);
                newVal = Math.max(min, Math.min(max, newVal));
                
                slider.value = newVal;
                // Dispatch input event to trigger UI display updates
                slider.dispatchEvent(new Event('input'));
            }
        });
    });
}

function triggerImmediateUpdate() {
    updatePipeline();
}

// ============================================================
// 3. WEBCAM INTERFACE & HUD
// ============================================================

async function initCamera() {
    const webcam = document.getElementById('webcam');
    const startBtn = document.getElementById('btn-start-camera');
    const captureBtn = document.getElementById('btn-capture');
    const placeholder = document.getElementById('camera-placeholder');
    const overlay = document.getElementById('camera-overlay');
    const scannerHud = document.getElementById('scanner-hud');
    const statusBadge = document.getElementById('camera-status-badge');

    startBtn.addEventListener('click', async () => {
        if (state.cameraStream) {
            // Stop Camera
            state.cameraStream.getTracks().forEach(track => track.stop());
            state.cameraStream = null;
            webcam.srcObject = null;
            startBtn.innerHTML = `<i class="fa-solid fa-video"></i> Toggle Camera`;
            captureBtn.disabled = true;
            placeholder.style.display = 'flex';
            overlay.style.display = 'none';
            scannerHud.style.display = 'none';
            statusBadge.textContent = "Standby";
            statusBadge.className = "badge badge-outline";
        } else {
            // Start Camera
            try {
                const stream = await navigator.mediaDevices.getUserMedia({ 
                    video: { width: 320, height: 240, facingMode: 'user' } 
                });
                state.cameraStream = stream;
                webcam.srcObject = stream;
                startBtn.innerHTML = `<i class="fa-solid fa-video-slash"></i> Stop Camera`;
                captureBtn.disabled = false;
                placeholder.style.display = 'none';
                overlay.style.display = 'block';
                scannerHud.style.display = 'block';
                statusBadge.textContent = "VISION ACTIVE";
                statusBadge.className = "badge badge-outline text-success";
            } catch (err) {
                console.error("Camera access failed:", err);
                alert("Could not access camera. Please check permissions.");
            }
        }
    });

    captureBtn.addEventListener('click', () => {
        if (!state.cameraStream) return;

        const canvas = document.getElementById('photo-canvas');
        canvas.width = webcam.videoWidth;
        canvas.height = webcam.videoHeight;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(webcam, 0, 0, canvas.width, canvas.height);
        
        const base64 = canvas.toDataURL('image/jpeg', 0.85);
        state.capturedImageBase64 = base64;

        // Show preview
        const previewBox = document.getElementById('preview-box');
        const capturedImg = document.getElementById('captured-img');
        capturedImg.src = base64;
        previewBox.style.display = 'flex';

        // Run immediate analysis
        updatePipeline();
    });

    document.getElementById('btn-clear-capture').addEventListener('click', () => {
        state.capturedImageBase64 = null;
        document.getElementById('preview-box').style.display = 'none';
        document.getElementById('captured-img').src = '';
        updatePipeline();
    });
}

// ============================================================
// 4. LEAFLET MAP & GPS ROUTE CALCULATION
// ============================================================

function initMap() {
    const defaultLoc = [41.8902, 12.4922];
    
    state.map = L.map('map-container').setView(defaultLoc, 16);
    
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
        subdomains: 'abcd',
        maxZoom: 20
    }).addTo(state.map);

    state.normalRouteLine = L.polyline([], {color: '#10b981', weight: 5, opacity: 0.8}).addTo(state.map);

    // Map Click Listener
    state.map.on('click', (e) => {
        const latlng = e.latlng;
        
        if (state.isDrawingRoute) {
            // Draw normal path
            state.routePoints.push(latlng);
            state.normalRouteLine.setLatLngs(state.routePoints);
            
            // Add a temporary marker for the route start/nodes
            if (state.routePoints.length === 1) {
                L.marker(latlng, {
                    icon: L.divIcon({className: 'route-start-marker', html: '<i class="fa-solid fa-flag text-success" style="font-size: 16px;"></i>', iconSize: [20, 20]})
                }).addTo(state.map);
            }
        } else {
            // Drawing completed, this click represents a DETOUR
            simulateDetour(latlng);
        }
    });

    // Double-click to complete drawing the route
    state.map.on('dblclick', (e) => {
        if (state.isDrawingRoute && state.routePoints.length > 1) {
            state.isDrawingRoute = false;
            alert("Route drawing complete! Click anywhere off the green line to simulate route deviation/detours.");
        }
    });

    // Reset Route
    document.getElementById('btn-clear-route').addEventListener('click', () => {
        state.isDrawingRoute = true;
        state.routePoints = [];
        state.normalRouteLine.setLatLngs([]);
        if (state.detourMarker) {
            state.map.removeLayer(state.detourMarker);
            state.detourMarker = null;
        }
        
        // Remove all markers
        state.map.eachLayer((layer) => {
            if (layer instanceof L.Marker) {
                state.map.removeLayer(layer);
            }
        });

        // Reset values
        state.gpsParameters.deviation_m = 0.0;
        state.gpsParameters.stationary_off_route_min = 0.0;
        updateGpsLabels();
        updatePipeline();
    });

    // Track Real GPS
    const gpsBtn = document.getElementById('btn-gps-track');
    gpsBtn.addEventListener('click', () => {
        if (state.gpsWatchId) {
            // Stop tracking
            navigator.geolocation.clearWatch(state.gpsWatchId);
            state.gpsWatchId = null;
            gpsBtn.innerHTML = `<i class="fa-solid fa-location-crosshairs"></i> Track Real GPS`;
            gpsBtn.classList.remove('active');
        } else {
            // Start tracking
            if (!navigator.geolocation) {
                alert("Geolocation is not supported by your browser");
                return;
            }
            gpsBtn.innerHTML = `<i class="fa-solid fa-stop"></i> Stop GPS Track`;
            gpsBtn.classList.add('active');
            
            state.gpsWatchId = navigator.geolocation.watchPosition(
                handleGpsSuccess,
                (err) => {
                    console.error("GPS error:", err);
                    alert("Unable to retrieve GPS position.");
                    gpsBtn.click();
                },
                { enableHighAccuracy: true }
            );
        }
    });
}

function handleGpsSuccess(position) {
    const lat = position.coords.latitude;
    const lng = position.coords.longitude;
    const latlng = L.latLng(lat, lng);
    
    state.map.setView(latlng, 17);

    const now = Date.now();
    let speed = position.coords.speed ? (position.coords.speed * 3.6) : 5.5; // m/s to km/h
    
    if (state.lastLatLng && state.lastGpsTime) {
        const dt = (now - state.lastGpsTime) / 1000.0;
        state.gpsParameters.time_since_gps_sec = Math.min(120, Math.max(5, dt));
        
        if (!position.coords.speed) {
            const dist = state.lastLatLng.distanceTo(latlng);
            speed = (dist / dt) * 3.6;
        }
        
        state.gpsParameters.speed_delta = Math.abs(speed - state.lastSpeed);
    }
    
    state.lastLatLng = latlng;
    state.lastGpsTime = now;
    state.lastSpeed = speed;
    state.gpsParameters.speed_kmh = Math.min(30, speed);

    if (state.isDrawingRoute) {
        state.routePoints.push(latlng);
        state.normalRouteLine.setLatLngs(state.routePoints);
        state.gpsParameters.deviation_m = 0.0;
    } else {
        simulateDetour(latlng, false);
    }
    
    updateGpsLabels();
    updatePipeline();
}

function simulateDetour(latlng, drawMarker = true) {
    if (state.routePoints.length === 0) return;

    let minDistance = Infinity;
    let closestPoint = null;
    
    for (let i = 0; i < state.routePoints.length; i++) {
        const dist = latlng.distanceTo(state.routePoints[i]);
        if (dist < minDistance) {
            minDistance = dist;
            closestPoint = state.routePoints[i];
        }
    }

    state.gpsParameters.deviation_m = minDistance;

    if (minDistance > 50) {
        state.gpsParameters.stationary_off_route_min += 0.2;
    } else {
        state.gpsParameters.stationary_off_route_min = Math.max(0, state.gpsParameters.stationary_off_route_min - 0.5);
    }

    if (drawMarker) {
        if (state.detourMarker) {
            state.detourMarker.setLatLng(latlng);
        } else {
            state.detourMarker = L.marker(latlng, {
                icon: L.divIcon({className: 'detour-marker', html: '<i class="fa-solid fa-person-circle-exclamation text-danger" style="font-size: 22px; filter: drop-shadow(0 0 6px rgba(239,68,68,0.6));"></i>', iconSize: [24, 24]})
            }).addTo(state.map);
        }
        
        const bounds = L.latLngBounds([state.routePoints, latlng]);
        state.map.fitBounds(bounds, {padding: [50, 50]});
    }

    updateGpsLabels();
    updatePipeline();
}

function updateGpsLabels() {
    document.getElementById('val-deviation').textContent = `${state.gpsParameters.deviation_m.toFixed(1)} m`;
    document.getElementById('val-speed').textContent = `${state.gpsParameters.speed_kmh.toFixed(1)} km/h`;
    document.getElementById('val-stationary').textContent = `${state.gpsParameters.stationary_off_route_min.toFixed(1)} min`;
}

// ============================================================
// 5. ACTIVITY SENSOR WAVEFORM ANIMATION
// ============================================================

function initSensors() {
    const canvas = document.getElementById('sensor-canvas');
    const ctx = canvas.getContext('2d');
    let offset = 0;
    
    const getWaveConfig = () => {
        switch (state.activeActivityClass) {
            case 2: // Sitting
                return { freq: 0.05, amp: 2, noise: 0.5 };
            case 3: // Standing
                return { freq: 0.08, amp: 3, noise: 0.8 };
            case 5: // Walking
                return { freq: 0.15, amp: 10, noise: 2.0 };
            case 1: // Jogging
                return { freq: 0.28, amp: 22, noise: 4.0 };
            case 4: // Upstairs
                return { freq: 0.20, amp: 15, noise: 3.0 };
            case 0: // Downstairs
                return { freq: 0.22, amp: 17, noise: 3.5 };
            default:
                return { freq: 0.1, amp: 5, noise: 1 };
        }
    };

    function drawWave() {
        if (!canvas.parentElement) return;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        const w = canvas.width;
        const h = canvas.height;
        const cfg = getWaveConfig();
        
        const axes = [
            { color: '#ef4444', phase: 0, ampMult: 1.0 },     // X
            { color: '#10b981', phase: Math.PI / 3, ampMult: 0.8 }, // Y
            { color: '#3b82f6', phase: Math.PI / 1.5, ampMult: 1.2 }  // Z
        ];

        axes.forEach(axis => {
            ctx.beginPath();
            ctx.strokeStyle = axis.color;
            ctx.lineWidth = 1.5;
            ctx.globalAlpha = 0.8;
            
            for (let x = 0; x < w; x++) {
                const angle = (x * cfg.freq) + offset + axis.phase;
                const noiseVal = (Math.random() - 0.5) * cfg.noise;
                const y = (h / 2) + Math.sin(angle) * cfg.amp * axis.ampMult + noiseVal;
                
                if (x === 0) {
                    ctx.moveTo(x, y);
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        });

        offset += 0.08;
        requestAnimationFrame(drawWave);
    }
    
    function resizeCanvas() {
        if (canvas.parentElement) {
            canvas.width = canvas.parentElement.clientWidth;
            canvas.height = canvas.parentElement.clientHeight;
        }
    }
    window.addEventListener('resize', resizeCanvas);
    resizeCanvas();
    drawWave();

    const presetBtns = document.querySelectorAll('.btn-preset');
    presetBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            presetBtns.forEach(b => b.classList.remove('active'));
            const target = e.currentTarget;
            target.classList.add('active');
            
            state.activeActivityClass = parseInt(target.getAttribute('data-class'));
            state.activityConfidence = 0.90 + Math.random() * 0.09;
            
            updatePipeline();
        });
    });
}

function generateSyntheticSensorData() {
    const channels = 12;
    const timesteps = 100;
    const data = [];
    
    const actMap = {
        2: { f: 0.05, a: 0.1 },  // Sitting
        3: { f: 0.08, a: 0.15 }, // Standing
        5: { f: 0.15, a: 0.8 },  // Walking
        1: { f: 0.28, a: 2.0 },  // Jogging
        4: { f: 0.20, a: 1.2 },  // Upstairs
        0: { f: 0.22, a: 1.4 }   // Downstairs
    };
    
    const cfg = actMap[state.activeActivityClass] || actMap[2];
    
    for (let c = 0; c < channels; c++) {
        const channelData = [];
        const phase = c * (Math.PI / 6);
        for (let t = 0; t < timesteps; t++) {
            const angle = (t * cfg.f) + phase;
            const noise = (Math.random() - 0.5) * (cfg.a * 0.15);
            channelData.push(Math.sin(angle) * cfg.a + noise);
        }
        data.push(channelData);
    }
    return data;
}

// ============================================================
// 6. SOS EMERGENCY HOLD ACTION
// ============================================================

function initSosTrigger() {
    const liftCoverBtn = document.getElementById('btn-lift-cover');
    const closeCoverBtn = document.getElementById('btn-close-cover');
    const sosCover = document.getElementById('sos-cover');
    const sosExposed = document.getElementById('sos-exposed');
    const sosBtn = document.getElementById('btn-sos');
    const holdFill = document.getElementById('sos-hold-fill');
    const innerLabel = sosBtn.querySelector('.sos-inner-label');

    let holdTimer = null;
    let progressTimer = null;
    const holdDuration = 2000; // 2 seconds
    let startHoldTime = 0;
    
    // Lift / Close cover gates
    liftCoverBtn.addEventListener('click', () => {
        sosCover.classList.add('flipped');
        sosExposed.classList.remove('hidden');
        state.sosCoverOpen = true;
    });

    closeCoverBtn.addEventListener('click', () => {
        sosCover.classList.remove('flipped');
        sosExposed.classList.add('hidden');
        state.sosCoverOpen = false;
        
        // Reset SOS if it was active
        if (state.sosPressed) {
            state.sosPressed = false;
            sosBtn.classList.remove('active');
            innerLabel.textContent = "HOLD SOS";
            holdFill.style.strokeDashoffset = 276;
            updatePipeline();
        }
    });

    // Hold-to-trigger Event Listeners
    const startHold = (e) => {
        e.preventDefault();
        if (state.sosPressed) {
            // Tap to toggle off if active
            state.sosPressed = false;
            sosBtn.classList.remove('active');
            innerLabel.textContent = "HOLD SOS";
            holdFill.style.strokeDashoffset = 276;
            updatePipeline();
            return;
        }

        startHoldTime = Date.now();
        sosBtn.classList.add('holding');

        // Animation frame loop for ring fill
        const updateProgress = () => {
            if (!sosBtn.classList.contains('holding')) return;
            const elapsed = Date.now() - startHoldTime;
            const progress = Math.min(1.0, elapsed / holdDuration);
            // Circumference of r=44 is 276.46 ~ 276
            const offset = 276 - (progress * 276);
            holdFill.style.strokeDashoffset = offset;

            if (progress < 1.0) {
                requestAnimationFrame(updateProgress);
            }
        };
        requestAnimationFrame(updateProgress);

        // Timeout to trigger trigger
        holdTimer = setTimeout(() => {
            state.sosPressed = true;
            sosBtn.classList.remove('holding');
            sosBtn.classList.add('active');
            innerLabel.textContent = "ACTIVE";
            holdFill.style.strokeDashoffset = 0;
            playAlertSound();
            updatePipeline();
        }, holdDuration);
    };

    const cancelHold = () => {
        if (!state.sosPressed) {
            sosBtn.classList.remove('holding');
            holdFill.style.strokeDashoffset = 276;
        }
        if (holdTimer) {
            clearTimeout(holdTimer);
            holdTimer = null;
        }
    };

    sosBtn.addEventListener('mousedown', startHold);
    sosBtn.addEventListener('mouseup', cancelHold);
    sosBtn.addEventListener('mouseleave', cancelHold);
    
    sosBtn.addEventListener('touchstart', startHold, { passive: false });
    sosBtn.addEventListener('touchend', cancelHold);
    sosBtn.addEventListener('touchcancel', cancelHold);
}

// ============================================================
// 7. REAL-TIME JSON LOGGER
// ============================================================

function initLogActions() {
    const clearBtn = document.getElementById('btn-clear-logs');
    const logsCode = document.getElementById('logs-code');
    
    clearBtn.addEventListener('click', () => {
        logsCode.textContent = 'Waiting for system updates...';
    });
}

function writeTelemetryLog(payload, direction) {
    const logsCode = document.getElementById('logs-code');
    const timestamp = new Date().toLocaleTimeString();
    
    let formattedText = `\n[${timestamp}] --- TELEMETRY PAYLOAD (${direction}) ---\n`;
    formattedText += JSON.stringify(payload, null, 2);
    formattedText += `\n--------------------------------------------\n`;
    
    if (logsCode.textContent === 'Waiting for system updates...') {
        logsCode.textContent = '';
    }
    
    // Append at the top (newest first)
    logsCode.textContent = formattedText + logsCode.textContent;
}

// ============================================================
// 8. PIPELINE RUNNER & UI RENDERER
// ============================================================

let isUpdating = false;

async function updatePipeline() {
    if (isUpdating) return;
    isUpdating = true;

    try {
        const requestData = {
            face_image_base64: state.capturedImageBase64,
            eye_image_base64: state.capturedImageBase64, 
            fall_image_base64: state.capturedImageBase64,
            
            sensor_data: generateSyntheticSensorData(),
            sensor_activity_class_override: state.activeActivityClass,
            sensor_activity_conf_override: state.activityConfidence,
            
            deviation_m: state.gpsParameters.deviation_m,
            speed_kmh: state.gpsParameters.speed_kmh,
            heading_change_rate: state.gpsParameters.heading_change_rate,
            stationary_off_route_min: state.gpsParameters.stationary_off_route_min,
            time_since_gps_sec: state.gpsParameters.time_since_gps_sec,
            speed_delta: state.gpsParameters.speed_delta,
            
            crime_score: parseFloat(document.getElementById('slide-crime').value),
            hour: parseInt(document.getElementById('select-hour').value),
            weather: document.getElementById('select-weather').value,
            crowd_ppm2: parseFloat(document.getElementById('slide-crowd').value),
            geo_fence: document.getElementById('select-geofence').value,
            
            sos_pressed: state.sosPressed,
            hr_bpm: parseFloat(document.getElementById('slide-hr').value)
        };

        // Log sent payload
        writeTelemetryLog(requestData, 'OUTBOUND');

        const res = await fetch(`${API_BASE}/api/predict/full`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestData)
        });
        
        if (!res.ok) throw new Error("Backend classification error");
        
        const result = await res.json();
        
        // Log received response
        writeTelemetryLog(result, 'INBOUND');
        
        renderDashboard(result);
        
    } catch (err) {
        console.error("Pipeline update failed:", err);
    } finally {
        isUpdating = false;
    }
}

function renderDashboard(data) {
    const riskScore = data.overall_risk_score;
    const riskBand = data.risk_band;
    
    // 1. Overall Risk Score & Band
    document.getElementById('risk-value').textContent = riskScore.toFixed(1);
    document.getElementById('risk-band-name').textContent = riskBand.toUpperCase();
    
    // Update Circular Gauge
    const circle = document.getElementById('gauge-fill-circle');
    const offset = 264 - (riskScore / 100) * 264;
    circle.style.strokeDashoffset = offset;
    
    // Gauge colors & card themes
    const card = document.getElementById('risk-band-card');
    card.className = "card risk-card";
    
    let colorHex = '#10b981';
    if (riskBand === 'Safe') {
        card.classList.add('band-safe');
        colorHex = '#10b981';
    } else if (riskBand === 'Medium') {
        card.classList.add('band-medium');
        colorHex = '#f59e0b';
    } else if (riskBand === 'High') {
        card.classList.add('band-high');
        colorHex = '#f97316';
    } else if (riskBand === 'Critical') {
        card.classList.add('band-critical');
        colorHex = '#ef4444';
    }
    circle.style.stroke = colorHex;
    
    // Last Update Timestamp
    const now = new Date();
    document.getElementById('risk-update-time').textContent = `Last Engine Sync: ${now.toLocaleTimeString()}`;

    // 2. Decision Alerts Escalation
    const alertKeys = ['notify_tourist', 'alert_family', 'alert_police', 'dispatch_emergency'];
    alertKeys.forEach(key => {
        const active = data.alerts[key];
        const el = document.getElementById(`alert-${key}`);
        const statusEl = el.querySelector('.alert-status');
        
        if (active) {
            el.classList.add('active');
            statusEl.textContent = "ACTIVE";
            
            // Audio alerting for new alert activations
            if (!state.prevAlertsState[key]) {
                playAlertSound();
            }
        } else {
            el.classList.remove('active');
            statusEl.textContent = "OFF";
        }
        state.prevAlertsState[key] = active;
    });

    // 3. SHAP Feature Contributions
    const explainList = document.getElementById('explain-list');
    explainList.innerHTML = '';
    
    const contributions = data.contributions;
    if (Object.keys(contributions).length === 0) {
        explainList.innerHTML = '<div class="explain-empty">No dominant risk factors detected.</div>';
    } else {
        Object.entries(contributions).forEach(([name, val]) => {
            const percentage = Math.min(100, Math.max(0, val));
            
            const barContainer = document.createElement('div');
            barContainer.className = 'explain-bar-container';
            barContainer.innerHTML = `
                <div class="explain-bar-header">
                    <span class="explain-bar-name">${name}</span>
                    <span class="explain-bar-val">+${val.toFixed(1)}</span>
                </div>
                <div class="explain-bar-bg">
                    <div class="explain-bar-fill" style="width: ${percentage}%; background-color: ${colorHex}"></div>
                </div>
            `;
            explainList.appendChild(barContainer);
        });
    }

    // 4. Diagnostics & Perception Sub-models
    // HAR Activity
    const harClass = data.sub_scores.activity_recognition.class;
    const harConf = data.sub_scores.activity_recognition.confidence * 100;
    document.getElementById('diag-har').textContent = harClass;
    document.getElementById('diag-har-conf').textContent = `Conf: ${harConf.toFixed(0)}% (CNN+LSTM)`;

    // Fall Detection
    const fallDet = data.sub_scores.fall_detection.detected;
    const fallConf = data.sub_scores.fall_detection.confidence * 100;
    document.getElementById('diag-fall').textContent = fallDet ? "FALL DETECTED" : "Safe";
    document.getElementById('diag-fall').className = fallDet ? "diag-value text-red" : "diag-value";
    document.getElementById('diag-fall-conf').textContent = `Conf: ${fallConf.toFixed(0)}% (MobileNet)`;

    // Emotion
    const emoClass = data.sub_scores.emotion_recognition.class;
    const emoRisk = data.sub_scores.emotion_recognition.risk_score;
    document.getElementById('diag-emotion').textContent = `${emoClass.toUpperCase()} (Risk: ${emoRisk.toFixed(0)})`;
    document.getElementById('diag-emotion-conf').textContent = `Conf: ${(data.sub_scores.emotion_recognition.confidence * 100).toFixed(0)}% (FER2013)`;

    // Drowsiness
    const drowsy = data.sub_scores.drowsiness_detection.drowsy;
    const drowsyScore = data.sub_scores.drowsiness_detection.score;
    document.getElementById('diag-drowsy').textContent = drowsy ? "DROWSY/SLEEPY" : "Alert";
    document.getElementById('diag-drowsy').className = drowsy ? "diag-value text-orange" : "diag-value";
    document.getElementById('diag-drowsy-conf').textContent = `Eye Score: ${drowsyScore.toFixed(0)}% (MRL Eye)`;

    // Route Anomaly
    const routeScore = data.sub_scores.route_deviation.score;
    const routeAnom = data.sub_scores.route_deviation.anomaly;
    document.getElementById('diag-route').textContent = `${routeScore.toFixed(0)}% Risk`;
    document.getElementById('diag-route').className = routeAnom ? "diag-value text-red" : "diag-value";

    // Heart Rate Anomaly
    const hrScore = data.sub_scores.heart_rate_anomaly.score;
    document.getElementById('diag-hr').textContent = `${hrScore.toFixed(0)}% Deviation`;
    document.getElementById('diag-hr').className = hrScore > 60 ? "diag-value text-orange" : "diag-value";
}

// Emergency Sound Alerts using Browser Audio Context
let audioCtx = null;
function playAlertSound() {
    try {
        if (!audioCtx) {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }
        
        const osc = audioCtx.createOscillator();
        const gainNode = audioCtx.createGain();
        
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, audioCtx.currentTime); // A5 note
        osc.frequency.exponentialRampToValueAtTime(440, audioCtx.currentTime + 0.4);
        
        gainNode.gain.setValueAtTime(0.15, audioCtx.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.5);
        
        osc.connect(gainNode);
        gainNode.connect(audioCtx.destination);
        
        osc.start();
        osc.stop(audioCtx.currentTime + 0.5);
    } catch (e) {
        console.warn("Audio Context alert sound blocked by browser autoplay policy");
    }
}
