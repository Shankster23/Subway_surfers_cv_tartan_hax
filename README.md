# Subway Surfers CV - TartanHax Edition

A lightweight, browser-based endless runner game inspired by Subway Surfers, featuring **Computer Vision controls** powered by MediaPipe. Built from the ground up with extreme size optimization in mind.

## 🎮 Play Now

Simply open `index.html` in a modern web browser (Chrome, Edge, or Safari recommended for CV support). (hardware_game is seperate form this game)

## ✨ Features

- **🎯 Traditional Controls**: Swipe or arrow keys to move, jump, and slide
- **📷 Computer Vision Controls**: Use your body movements to control the game
  - **Jump**: Raise your arms or physically jump
  - **Slide**: Crouch or squat down
  - **Lane Change**: Move left or right in the camera view
- **📱 Mobile-Friendly**: Responsive design with touch controls
- **🎨 Minimalist Design**: Clean, modern UI with smooth animations
- **💾 Persistent High Scores**: Uses localStorage to save your best run


- Custom 2D Canvas renderer using perspective projection
- No external graphics libraries (no Three.js, Pixi.js, etc.)
- Procedural generation instead of sprite assets

**Code Minification Techniques**
- Ultra-short variable names (single letters where possible)
- Inline functions and arrow functions
- Removed all comments and whitespace in production code
- Combined related logic into compact expressions

**Zero Asset Loading**
- No images, fonts, or external files
- All graphics procedurally generated with Canvas API
- Emoji used for icons (built into browser)
- CSS gradients for visual effects

**MediaPipe from CDN**
- Computer Vision powered by external MediaPipe library
- Loaded from CDN and only works with wifi
- Only included when CV mode is enabled

## 🚀 Setup & Running

### Local Development
```bash
# Navigate to project directory
cd Subway_surfers_cv_tartan_hax

# Start a local server (required for MediaPipe/CV features)
python3 -m http.server 8000

# Open in browser
# Navigate to: http://localhost:8000
```

### Production Deployment
Simply upload `index.html` to any static hosting service:
- GitHub Pages
- Netlify
- Vercel
- Any web server

> **Note**: Computer Vision features require HTTPS or localhost (camera access restriction).

## 🎯 How to Play

### Keyboard Controls
- **Arrow Keys**: Move left/right, jump (up), slide (down)
- **Escape / P**: Pause game
- **C**: Recalibrate CV (when enabled)

### Touch Controls
- **Swipe Left/Right**: Change lanes
- **Swipe Up**: Jump
- **Swipe Down**: Slide
- **On-screen buttons**: Available at bottom of screen

### Computer Vision Controls
1. Click "CV: OFF" button (top right) to enable
2. Allow camera access when prompted
3. Follow calibration instructions:
   - Stand in center of camera view
   - Wait for "✅ Stable" indicator
   - Press SPACE or click CAPTURE
4. Play using body movements!

## 📊 Size Breakdown

| Component | Size | Notes |
|-----------|------|-------|
| Core Game Logic | ~15 KB | Rendering, physics, collision |
| UI & Styling | ~8 KB | CSS, modals, responsive design |
| CV Integration | ~15 KB | Calibration, pose detection logic |
| **Total (index.html)** | **~38 KB** | Self-contained, no dependencies |
| MediaPipe (CDN) | ~2 MB | External, loaded on-demand |

## 🛠️ Technical Stack

- **Vanilla JavaScript**: No frameworks
- **HTML5 Canvas**: 2D rendering with custom projection
- **MediaPipe Pose**: Body tracking for CV controls
- **CSS3**: Animations and responsive layout
- **LocalStorage**: Score persistence

## 📝 Development Timeline

- **Initial commit**: Unity-based project
- **0d8e0a5**: Core 15KB game achieved (vanilla JS rewrite)
- **520e5df**: Computer Vision integration
- **b255f90**: Cleanup & optimization (removed Unity assets)

## 🎓 Created By

**TartanHax Team**  
A demonstration of extreme web optimization and creative CV integration.

## 📜 License

See [LICENSE](LICENSE) file for details.

---

**🏆 Challenge**: Can you beat the high score? Can you make it even smaller?