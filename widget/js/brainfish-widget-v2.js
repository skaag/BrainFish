/**
 * BrainFish Widget v2 - Complete working implementation
 */

class BrainFishWidget {
    constructor(options = {}) {
        this.tasks = options.tasks || ['Sample Task'];
        this.theme = options.theme || 'red'; // Default to red theme
        this.fontSize = options.fontSize || 16;
        this.speed = options.speed || 120; // Increased default speed
        this.waveAmplitude = options.waveAmplitude || 20;
        this.waveFrequency = options.waveFrequency || 9; // Triple the frequency for more curves
        this.avoidMouse = options.avoidMouse !== false;
        this.prioritySpread = options.prioritySpread !== undefined ? options.prioritySpread : 80; // Vertical spread for priority positioning

        this.container = null;
        this.fishList = [];
        this.mouseX = -1000;
        this.mouseY = -1000;
        this.animationId = null;
        this.lastTime = 0;

        this.init();
    }

    init() {
        this.createContainer();
        this.createAllFish();
        this.setupEventListeners();
        this.startAnimation();
    }

    createContainer() {
        // Remove existing container
        const existing = document.querySelector('.brainfish-container');
        if (existing) existing.remove();

        this.container = document.createElement('div');
        this.container.className = 'brainfish-container';
        document.body.appendChild(this.container);
    }

    createAllFish() {
        this.fishList = [];

        this.tasks.forEach((task, index) => {
            const fishData = this.createSingleFish(task, index);
            this.fishList.push(fishData);
        });
    }

    createSingleFish(taskText, index) {
        // Create main fish container
        const fishContainer = document.createElement('div');
        fishContainer.className = 'brainfish';
        fishContainer.setAttribute('data-theme', this.theme);

        // Create fish parts
        const head = document.createElement('div');
        head.className = 'fish-part fish-head';

        const pectoral = document.createElement('div');
        pectoral.className = 'fish-part fish-pectoral';

        const ventral = document.createElement('div');
        ventral.className = 'fish-part fish-ventral';

        const tail = document.createElement('div');
        tail.className = 'fish-part fish-tail';

        // Add parts to container
        fishContainer.appendChild(head);
        fishContainer.appendChild(pectoral);
        fishContainer.appendChild(ventral);
        fishContainer.appendChild(tail);

        // Create letters for the task text
        const letters = [];
        const letterElements = [];
        for (let i = 0; i < taskText.length; i++) {
            const letter = document.createElement('span');
            letter.className = 'fish-letter';
            letter.textContent = taskText[i];
            letter.style.fontSize = `${this.fontSize}px`;
            fishContainer.appendChild(letter);
            letterElements.push(letter);
            letters.push(taskText[i]);
        }

        // Add to DOM
        this.container.appendChild(fishContainer);

        // Calculate priority-based Y offset (higher priority = higher on screen)
        // Use prioritySpread setting to control vertical separation
        const maxTasks = Math.max(this.tasks.length, 1);
        const priorityOffset = (index / Math.max(maxTasks - 1, 1)) * this.prioritySpread;

        // Return fish data object with random wave characteristics
        return {
            element: fishContainer,
            parts: {
                head: head,
                pectoral: pectoral,
                ventral: ventral,
                tail: tail
            },
            letters: letterElements,
            text: taskText,
            index: index,
            x: window.innerWidth + (index * 300), // Start off-screen with spacing
            baseY: 40,
            currentSpeed: this.speed,
            targetSpeed: this.speed,
            isAvoiding: false,
            // Individual wave characteristics for each fish
            wavePhase: Math.random() * Math.PI * 2, // Random phase offset
            waveAmplitude: 0.7 + Math.random() * 0.6, // Amplitude between 0.7 and 1.3
            waveFrequency: 0.8 + Math.random() * 0.4, // Frequency between 0.8 and 1.2
            baseYOffset: (Math.random() - 0.5) * 15 + priorityOffset // Random variation + priority offset
        };
    }

    calculateWormPath(x, fishIndex, fishData) {
        // Create a wave pattern based on X position with individual fish randomization
        const screenWidth = window.innerWidth;
        const progress = x / screenWidth;

        // Each fish gets its own random wave characteristics
        const phaseOffset = fishData ? fishData.wavePhase : (fishIndex * 0.5);
        const amplitudeMultiplier = fishData ? fishData.waveAmplitude : 1.0;
        const frequencyMultiplier = fishData ? fishData.waveFrequency : 1.0;

        const wave = Math.sin((progress * Math.PI * this.waveFrequency * frequencyMultiplier) + phaseOffset) * (this.waveAmplitude * amplitudeMultiplier);

        // Each fish also gets a slightly different base Y position
        const baseY = 40 + (fishData ? fishData.baseYOffset : 0);
        return baseY + wave;
    }

    calculateTangentAngle(x, fishIndex, fishData) {
        // Calculate the derivative of the worm path to get the tangent angle
        const delta = 5; // Small delta for derivative calculation
        const y1 = this.calculateWormPath(x - delta, fishIndex, fishData);
        const y2 = this.calculateWormPath(x + delta, fishIndex, fishData);
        const angle = Math.atan2(y2 - y1, delta * 2) * (180 / Math.PI);
        return angle;
    }

    updateFish(fish, deltaTime) {
        // Update speed based on mouse proximity
        if (this.avoidMouse) {
            const fishCenterX = fish.x + (fish.text.length * this.fontSize * 0.55 * 0.5); // Center of text
            const fishCenterY = this.calculateWormPath(fishCenterX, fish.index, fish);
            const distance = Math.sqrt(
                Math.pow(this.mouseX - fishCenterX, 2) +
                Math.pow(this.mouseY - fishCenterY, 2)
            );

            fish.isAvoiding = distance < 120;
            fish.targetSpeed = fish.isAvoiding ? this.speed * 3 : this.speed;

            // Smooth speed transition
            const speedDiff = fish.targetSpeed - fish.currentSpeed;
            fish.currentSpeed += speedDiff * 0.1;
        }

        // Update X position
        fish.x -= fish.currentSpeed * deltaTime;

        // Wrap around when fish goes off screen
        if (fish.x < -400) {
            fish.x = window.innerWidth + 100;
        }

        // Position the fish container (no rotation here)
        fish.element.style.transform = `translate(${fish.x}px, 0px)`;

        // Position individual parts relative to container - spread letters slightly
        const letterSpacing = this.fontSize * 0.55; // Increased from 0.45 to 0.55 for better spacing
        const textWidth = fish.text.length * letterSpacing;

        // Scale sprites based on font size (base size 16px)
        const spriteScale = this.fontSize / 16;

        // Calculate positions for each fish part along the wave path - adjusted for better text alignment
        const textStartOffset = -5; // Move text slightly toward tail
        const headX = fish.x - (25 * spriteScale);
        const pectoralX = fish.x + textStartOffset + (textWidth * 0.15);
        const ventralX = fish.x + textStartOffset + (textWidth * 0.6); // Moved closer to tail
        const tailX = fish.x + textStartOffset + textWidth - 5; // Closer to last letter

        // Position fish parts individually on the wave path with rotation and scaling
        const headY = this.calculateWormPath(headX, fish.index, fish);
        const headAngle = this.calculateTangentAngle(headX, fish.index, fish);
        fish.parts.head.style.transform = `translate(${-25 * spriteScale}px, ${headY - (15 * spriteScale)}px) rotate(${headAngle}deg) scale(${spriteScale})`;

        const pectoralY = this.calculateWormPath(pectoralX, fish.index, fish);
        const pectoralAngle = this.calculateTangentAngle(pectoralX, fish.index, fish);
        fish.parts.pectoral.style.transform = `translate(${textStartOffset + (textWidth * 0.15)}px, ${pectoralY - (25 * spriteScale)}px) rotate(${pectoralAngle}deg) scale(${spriteScale})`;

        const ventralY = this.calculateWormPath(ventralX, fish.index, fish);
        const ventralAngle = this.calculateTangentAngle(ventralX, fish.index, fish);
        fish.parts.ventral.style.transform = `translate(${textStartOffset + (textWidth * 0.6)}px, ${ventralY - (10 * spriteScale)}px) rotate(${ventralAngle}deg) scale(${spriteScale})`;

        const tailY = this.calculateWormPath(tailX, fish.index, fish);
        const tailAngle = this.calculateTangentAngle(tailX, fish.index, fish);
        fish.parts.tail.style.transform = `translate(${textStartOffset + textWidth - 5}px, ${tailY - (10 * spriteScale)}px) rotate(${tailAngle}deg) scale(${spriteScale})`;

        // Position and scale letters with wave effect - each follows the path
        fish.letters.forEach((letter, i) => {
            const letterX = fish.x + textStartOffset + (i * letterSpacing);
            const letterY = this.calculateWormPath(letterX, fish.index, fish);
            const letterProgress = i / (fish.letters.length - 1);

            // Position letter on the wave path with text offset
            letter.style.transform = `translate(${textStartOffset + (i * letterSpacing)}px, ${letterY}px)`;

            // Scale letters (bigger in middle, smaller at ends)
            let scale = 1.0;
            if (letterProgress < 0.3) {
                scale = 0.8 + (letterProgress / 0.3) * 0.2;
            } else if (letterProgress > 0.7) {
                scale = 1.0 - ((letterProgress - 0.7) / 0.3) * 0.3;
            }

            letter.style.fontSize = `${this.fontSize * scale}px`;
        });
    }

    startAnimation() {
        const animate = (currentTime) => {
            // Calculate delta time in seconds
            const deltaTime = this.lastTime ? (currentTime - this.lastTime) / 1000 : 0;
            this.lastTime = currentTime;

            // Skip large delta times (e.g., when tab becomes active again)
            if (deltaTime > 0.1) {
                this.animationId = requestAnimationFrame(animate);
                return;
            }

            // Update each fish
            this.fishList.forEach(fish => {
                this.updateFish(fish, deltaTime);
            });

            this.animationId = requestAnimationFrame(animate);
        };

        this.animationId = requestAnimationFrame(animate);
    }

    setupEventListeners() {
        if (this.avoidMouse) {
            document.addEventListener('mousemove', (e) => {
                this.mouseX = e.clientX;
                this.mouseY = e.clientY;
            });
        }

        // Handle window resize
        window.addEventListener('resize', () => {
            this.fishList.forEach((fish, index) => {
                if (fish.x > window.innerWidth) {
                    fish.x = window.innerWidth + (index * 300);
                }
            });
        });
    }

    updateTasks(newTasks) {
        this.destroy();
        this.tasks = newTasks;
        this.init();
    }

    destroy() {
        if (this.animationId) {
            cancelAnimationFrame(this.animationId);
            this.animationId = null;
        }

        if (this.container) {
            this.container.remove();
            this.container = null;
        }

        this.fishList = [];
    }
}

// Auto-initialize if config is found
if (typeof window !== 'undefined') {
    document.addEventListener('DOMContentLoaded', () => {
        if (window.brainfishConfig) {
            window.brainfishWidget = new BrainFishWidget(window.brainfishConfig);
        }
    });
}

// Export for use as module
if (typeof module !== 'undefined' && module.exports) {
    module.exports = BrainFishWidget;
}