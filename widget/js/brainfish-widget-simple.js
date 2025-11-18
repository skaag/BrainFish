/**
 * BrainFish Widget - Simplified working version
 */

class BrainFishWidget {
    constructor(options = {}) {
        this.tasks = options.tasks || ['Sample Task'];
        this.fontSize = options.fontSize || 16;
        this.theme = options.theme || 'blue';
        this.speed = options.speed || 50; // pixels per second
        this.waveHeight = options.waveHeight || 15;
        this.avoidMouse = options.avoidMouse !== false;

        this.container = null;
        this.fish = [];
        this.mouseX = -1000;
        this.mouseY = -1000;

        this.init();
    }

    init() {
        this.createContainer();
        this.createFish();
        this.bindEvents();
        this.animate();
    }

    createContainer() {
        const existing = document.getElementById('brainfish-widget');
        if (existing) existing.remove();

        this.container = document.createElement('div');
        this.container.id = 'brainfish-widget';
        this.container.className = 'brainfish-widget';
        this.container.setAttribute('data-theme', this.theme);
        this.container.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 80px;
            z-index: 9999;
            pointer-events: none;
            overflow: hidden;
        `;
        document.body.appendChild(this.container);
    }

    createFish() {
        this.tasks.forEach((task, index) => {
            const fish = {
                task: task,
                index: index,
                x: window.innerWidth + (index * 300),
                y: 40,
                speed: this.speed * (0.8 + Math.random() * 0.4),
                element: null,
                isAvoiding: false
            };

            // Create fish container
            const fishEl = document.createElement('div');
            fishEl.className = 'fish';
            fishEl.style.cssText = `
                position: absolute;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-weight: bold;
                font-size: ${this.fontSize}px;
                color: ${this.getThemeColor()};
                text-shadow: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000;
                white-space: nowrap;
                pointer-events: none;
            `;

            // Add fish graphics (simplified for now)
            const textSpan = document.createElement('span');
            textSpan.textContent = '🐟 ' + task;
            fishEl.appendChild(textSpan);

            this.container.appendChild(fishEl);
            fish.element = fishEl;
            this.fish.push(fish);
        });
    }

    getThemeColor() {
        const colors = {
            blue: '#007AFF',
            green: '#34C759',
            orange: '#FF9500',
            red: '#FF3B30',
            purple: '#AF52DE'
        };
        return colors[this.theme] || colors.blue;
    }

    wormPath(x, index) {
        const screenPercent = x / window.innerWidth;
        const wave = Math.sin(screenPercent * Math.PI * 3 + index * 0.8) * this.waveHeight;
        return 40 + wave;
    }

    animate() {
        const update = () => {
            this.fish.forEach(fish => {
                // Update position
                const speed = fish.isAvoiding ? fish.speed * 3 : fish.speed;
                fish.x -= speed / 30; // Approximate 30fps

                // Reset when off screen
                if (fish.x < -200) {
                    fish.x = window.innerWidth + 100;
                }

                // Calculate Y with wave
                fish.y = this.wormPath(fish.x, fish.index);

                // Check mouse proximity
                if (this.avoidMouse) {
                    const dist = Math.sqrt(
                        Math.pow(this.mouseX - fish.x, 2) +
                        Math.pow(this.mouseY - fish.y, 2)
                    );
                    fish.isAvoiding = dist < 100;
                }

                // Apply position
                fish.element.style.transform = `translate(${fish.x}px, ${fish.y}px)`;
            });

            requestAnimationFrame(update);
        };

        requestAnimationFrame(update);
    }

    bindEvents() {
        if (this.avoidMouse) {
            document.addEventListener('mousemove', (e) => {
                this.mouseX = e.clientX;
                this.mouseY = e.clientY;
            });
        }
    }

    updateTasks(newTasks) {
        this.container.innerHTML = '';
        this.fish = [];
        this.tasks = newTasks;
        this.createFish();
    }

    destroy() {
        if (this.container) {
            this.container.remove();
        }
    }
}

// Auto-init
document.addEventListener('DOMContentLoaded', () => {
    if (window.brainfishConfig) {
        window.brainfish = new BrainFishWidget(window.brainfishConfig);
    }
});