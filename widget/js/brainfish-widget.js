/**
 * BrainFish Widget - JavaScript implementation
 * Mimics the macOS BrainFish app behavior for web demonstration
 */

class BrainFishWidget {
    constructor(options = {}) {
        this.tasks = options.tasks || ['Sample Task'];
        this.fontSize = options.fontSize || 16;
        this.theme = options.theme || 'blue';
        this.speed = options.speed || 50; // pixels per second
        this.waveHeight = options.waveHeight || 15;
        this.waveFrequency = options.waveFrequency || 3.0;
        this.avoidMouse = options.avoidMouse !== false;

        this.container = null;
        this.fish = [];
        this.mouseX = -1000;
        this.mouseY = -1000;
        this.animationFrame = null;
        this.lastTime = 0;

        this.init();
    }

    init() {
        this.createContainer();
        this.createFish();
        this.bindEvents();
        this.startAnimation();
    }

    createContainer() {
        // Remove existing widget if present
        const existing = document.getElementById('brainfish-widget');
        if (existing) {
            existing.remove();
        }

        this.container = document.createElement('div');
        this.container.id = 'brainfish-widget';
        this.container.className = 'brainfish-widget';
        this.container.setAttribute('data-theme', this.theme);
        document.body.appendChild(this.container);
    }

    createFish() {
        this.fish = [];
        const staggerDelay = 1000; // 1 second between fish

        this.tasks.forEach((task, index) => {
            const fishElement = this.createFishElement(task, index);
            this.container.appendChild(fishElement);

            const fishData = {
                element: fishElement,
                task: task,
                index: index,
                x: window.innerWidth + (index * 200), // Start off-screen with spacing
                baseY: 30, // Base Y position
                speed: this.speed * (0.8 + Math.random() * 0.4), // Slight speed variation
                startTime: Date.now() + (index * staggerDelay),
                avoidanceSpeed: this.speed * 4,
                isAvoiding: false,
                parts: {
                    head: fishElement.querySelector('.fish-head'),
                    pectoralFins: fishElement.querySelector('.fish-fins-pectoral'),
                    ventralFins: fishElement.querySelector('.fish-fins-ventral'),
                    tail: fishElement.querySelector('.fish-tail'),
                    letters: Array.from(fishElement.querySelectorAll('.fish-letter'))
                }
            };

            this.fish.push(fishData);
        });
    }

    createFishElement(task, index) {
        const fish = document.createElement('div');
        fish.className = 'fish';
        fish.style.fontSize = `${this.fontSize}px`;

        // Create fish parts
        const head = document.createElement('div');
        head.className = 'fish-part fish-head';

        const pectoralFins = document.createElement('div');
        pectoralFins.className = 'fish-part fish-fins-pectoral';

        const ventralFins = document.createElement('div');
        ventralFins.className = 'fish-part fish-fins-ventral';

        const tail = document.createElement('div');
        tail.className = 'fish-part fish-tail';

        // Create letters
        const letters = task.split('').map((letter, letterIndex) => {
            const letterEl = document.createElement('span');
            letterEl.className = 'fish-letter';
            letterEl.textContent = letter;
            return letterEl;
        });

        // Add all elements to fish
        fish.appendChild(head);
        fish.appendChild(pectoralFins);
        fish.appendChild(ventralFins);
        fish.appendChild(tail);
        letters.forEach(letter => fish.appendChild(letter));

        return fish;
    }

    wormPath(x, fishIndex) {
        const screenPercent = x / window.innerWidth;
        const baseY = this.container.offsetHeight * 0.5; // Middle of widget height
        const wave = Math.sin(screenPercent * Math.PI * this.waveFrequency + fishIndex * 0.8) * this.waveHeight;
        return baseY + wave;
    }

    updateFish(fish, currentTime) {
        const elapsed = currentTime - fish.startTime;
        if (elapsed < 0) return; // Fish hasn't started yet

        // Calculate position
        const deltaTime = (currentTime - this.lastTime) / 1000;
        const currentSpeed = fish.isAvoiding ? fish.avoidanceSpeed : fish.speed;
        fish.x -= currentSpeed * deltaTime;

        // Reset position when fish goes off screen
        if (fish.x < -300) {
            fish.x = window.innerWidth + 100;
        }

        // Calculate Y position using worm path
        const y = this.wormPath(fish.x, fish.index);

        // Mouse avoidance logic
        if (this.avoidMouse) {
            const mouseDistance = Math.sqrt(
                Math.pow(this.mouseX - fish.x, 2) +
                Math.pow(this.mouseY - y, 2)
            );
            fish.isAvoiding = mouseDistance < 120;
        }

        // Position fish parts
        this.positionFishParts(fish, fish.x, y);
    }

    positionFishParts(fish, x, y) {
        const letterSpacing = this.fontSize * 0.6;
        const textWidth = fish.task.length * letterSpacing;

        // Calculate positions for each part
        const headX = x - 30; // Offset for head
        const pectoralX = x + textWidth * 0.15;
        const ventralX = x + textWidth * 0.4;
        const tailX = x + textWidth;

        // Position whole fish container
        fish.element.style.transform = `translateX(${x}px)`;

        // Position each part relative to the fish container
        if (fish.parts.head) {
            fish.parts.head.style.left = '-30px';
            fish.parts.head.style.top = `${y - 37}px`; // Center vertically
        }

        if (fish.parts.pectoralFins) {
            fish.parts.pectoralFins.style.left = `${textWidth * 0.15}px`;
            fish.parts.pectoralFins.style.top = `${y - 56}px`;
        }

        if (fish.parts.ventralFins) {
            fish.parts.ventralFins.style.left = `${textWidth * 0.4}px`;
            fish.parts.ventralFins.style.top = `${y - 35}px`;
        }

        if (fish.parts.tail) {
            fish.parts.tail.style.left = `${textWidth + 20}px`;
            fish.parts.tail.style.top = `${y - 31}px`;
        }

        // Position letters
        fish.parts.letters.forEach((letter, i) => {
            const letterX = i * letterSpacing;
            const letterWaveY = Math.sin((x + letterX) / 100) * 5; // Add small wave to letters
            letter.style.left = `${letterX}px`;
            letter.style.top = `${y + letterWaveY}px`;

            // Apply scaling effect like in the original
            const scale = this.getLetterScale(i, fish.parts.letters.length);
            letter.style.fontSize = `${this.fontSize * scale}px`;
        });
    }

    getLetterScale(index, total) {
        const norm = index / (total - 1);
        const pectoralNorm = 0.15;
        const ventralNorm = 0.3;

        if (norm <= pectoralNorm) {
            return 1.0 + 0.1 * (norm / pectoralNorm);
        } else if (norm <= ventralNorm) {
            const factor = (norm - pectoralNorm) / (ventralNorm - pectoralNorm);
            return 1.1 - 0.2 * factor;
        } else {
            const factor = (norm - ventralNorm) / (1 - ventralNorm);
            return 0.9 - 0.4 * factor;
        }
    }

    bindEvents() {
        if (this.avoidMouse) {
            document.addEventListener('mousemove', (e) => {
                this.mouseX = e.clientX;
                this.mouseY = e.clientY;
            });
        }

        // Handle window resize
        window.addEventListener('resize', () => {
            this.fish.forEach(fish => {
                if (fish.x < 0) {
                    fish.x = window.innerWidth + 100;
                }
            });
        });
    }

    startAnimation() {
        const animate = (currentTime) => {
            if (this.lastTime === 0) {
                this.lastTime = currentTime;
            }

            this.fish.forEach(fish => this.updateFish(fish, currentTime));

            this.lastTime = currentTime;
            this.animationFrame = requestAnimationFrame(animate);
        };

        // Start the animation
        this.lastTime = 0;
        this.animationFrame = requestAnimationFrame(animate);
    }

    updateTasks(newTasks) {
        this.tasks = newTasks;
        this.stop();
        this.createFish();
        this.startAnimation();
    }

    stop() {
        if (this.animationFrame) {
            cancelAnimationFrame(this.animationFrame);
            this.animationFrame = null;
        }
    }

    destroy() {
        this.stop();
        if (this.container) {
            this.container.remove();
        }
    }
}

// Auto-initialize if brainfish-config is found
document.addEventListener('DOMContentLoaded', () => {
    const config = window.brainfishConfig;
    if (config) {
        window.brainfish = new BrainFishWidget(config);
    }
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = BrainFishWidget;
}