# BrainFish Widget

A JavaScript widget that brings the BrainFish macOS app experience to the web. Watch your tasks swim across the top of any webpage with realistic fish animations and mouse avoidance behavior.

## Features

- 🐟 **Realistic Fish Animation**: Swimming fish that follow wave-based paths
- 🖱️ **Mouse Avoidance**: Fish swim faster when your cursor gets close
- 🎨 **Customizable Themes**: Choose from multiple color schemes
- 📱 **Responsive Design**: Works on desktop and mobile devices
- ⚡ **Lightweight**: Optimized sprite sheet for fast loading
- 🔧 **Easy Integration**: Drop-in solution with minimal setup

## Quick Start

1. **Download the widget files** and upload to your web server
2. **Include the CSS and JavaScript** in your HTML:

```html
<link rel="stylesheet" href="path/to/brainfish-widget.css">
<script src="path/to/brainfish-widget.js"></script>
```

3. **Configure your tasks**:

```html
<script>
window.brainfishConfig = {
    tasks: [
        'Finish project proposal',
        'Review team feedback',
        'Schedule client meeting',
        'Update documentation'
    ],
    theme: 'blue',
    fontSize: 16,
    speed: 50,
    avoidMouse: true
};
</script>
```

That's it! The fish will automatically start swimming when the page loads.

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tasks` | Array | `['Sample Task']` | List of tasks to display as swimming fish |
| `theme` | String | `'blue'` | Color theme: 'blue', 'green', 'orange', 'red', 'purple' |
| `fontSize` | Number | `16` | Font size for task text in pixels |
| `speed` | Number | `50` | Base swimming speed in pixels per second |
| `waveHeight` | Number | `15` | Height of the wave motion in pixels |
| `waveFrequency` | Number | `3.0` | Frequency of the wave pattern |
| `avoidMouse` | Boolean | `true` | Enable mouse cursor avoidance behavior |

## Programmatic Usage

You can also control the widget programmatically:

```javascript
// Create a new widget instance
const widget = new BrainFishWidget({
    tasks: ['Task 1', 'Task 2', 'Task 3'],
    theme: 'green',
    fontSize: 18
});

// Update tasks dynamically
widget.updateTasks([
    'New urgent task',
    'Follow up with client',
    'Prepare presentation'
]);

// Stop the animation
widget.stop();

// Restart the animation
widget.startAnimation();

// Completely remove the widget
widget.destroy();
```

## Customization

### Custom Colors

You can add custom color themes by modifying the CSS:

```css
.brainfish-widget[data-theme="custom"] .fish-letter {
    color: #your-color;
}
```

### Custom Positioning

By default, the widget appears at the top of the page. You can customize the positioning:

```css
.brainfish-widget {
    top: 100px; /* Move down from top */
    height: 80px; /* Make taller */
}
```

### Custom Fish Parts

The fish graphics use a sprite sheet. You can replace `fish-sprite.png` with your own graphics while maintaining the same dimensions and layout.

## File Structure

```
widget/
├── assets/
│   ├── fish-sprite.png          # Combined sprite sheet
│   ├── koi-head-opt.png         # Individual parts (fallback)
│   ├── koi-fins-pectoral-opt.png
│   ├── koi-fins-ventral-opt.png
│   └── koi-tail-opt.png
├── css/
│   └── brainfish-widget.css     # Widget styles
├── js/
│   └── brainfish-widget.js      # Widget JavaScript
├── demo.html                    # Live demo page
└── README.md                    # This file
```

## Browser Support

- Chrome 60+
- Firefox 55+
- Safari 12+
- Edge 79+
- Mobile browsers (iOS Safari 12+, Chrome Mobile 60+)

## Performance

The widget is optimized for performance:
- Uses `requestAnimationFrame` for smooth 60fps animation
- Sprite sheet reduces HTTP requests
- GPU-accelerated CSS transforms
- Minimal DOM manipulation

## Examples

### Basic Integration
```html
<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" href="css/brainfish-widget.css">
</head>
<body>
    <h1>My Website</h1>
    <p>Content here...</p>

    <script src="js/brainfish-widget.js"></script>
    <script>
    window.brainfishConfig = {
        tasks: ['Learn JavaScript', 'Build awesome websites', 'Have fun!'],
        theme: 'purple'
    };
    </script>
</body>
</html>
```

### Dynamic Task Management
```javascript
// Load tasks from an API
fetch('/api/tasks')
    .then(response => response.json())
    .then(tasks => {
        const widget = new BrainFishWidget({
            tasks: tasks.map(task => task.title),
            theme: 'blue'
        });
    });

// Update tasks when they change
function updateTaskList(newTasks) {
    if (window.brainfish) {
        window.brainfish.updateTasks(newTasks);
    }
}
```

## License

This widget is part of the BrainFish project. Feel free to use it to promote productivity and the BrainFish macOS app!

## About BrainFish

BrainFish is a macOS desktop application designed to help people with ADHD stay focused on their tasks. The full app includes:

- Task management with persistence
- Pomodoro timer integration
- Customizable fish behavior and appearance
- Global keyboard shortcuts
- Menu bar integration
- Sleep/wake cycle management

[Download BrainFish for macOS](https://example.com/download)