import { ParameterType } from '../types.js';

export default class ImageSwipe {
  static info = {
    name: 'image-swipe',
    version: '1.0.0',
    description: 'Shows a single image the participant swipes left or right to respond.',
    parameters: {
      stimulus: {
        type: ParameterType.IMAGE,
        default: undefined,
        array: false,
        description: 'URL of the image to display.',
      },
      prompt: {
        type: ParameterType.HTML_STRING,
        default: null,
        array: false,
        description: 'Optional instructions shown above the image (HTML allowed).',
      },
      left_label: {
        type: ParameterType.STRING,
        default: 'No',
        array: false,
        description: 'Label for the left-swipe action.',
      },
      right_label: {
        type: ParameterType.STRING,
        default: 'Yes',
        array: false,
        description: 'Label for the right-swipe action.',
      },
      show_buttons: {
        type: ParameterType.BOOL,
        default: true,
        array: false,
        description: 'Show clickable left / right buttons below the image.',
      },
      image_width: {
        type: ParameterType.INT,
        default: 360,
        array: false,
        description: 'Width of the image card in pixels.',
      },
      image_height: {
        type: ParameterType.INT,
        default: 360,
        array: false,
        description: 'Height of the image card in pixels.',
      },
      swipe_threshold: {
        type: ParameterType.INT,
        default: 80,
        array: false,
        description: 'Minimum drag distance in pixels to register as a swipe.',
      },
    },
  };

  constructor(jsPsych) {
    this.jsPsych = jsPsych;
  }

  trial(displayElement, trial) {
    const startTime = performance.now();
    let responded = false;

    // ── Render ──────────────────────────────────────────────────────────────
    displayElement.innerHTML = `
      <div style="display:flex;flex-direction:column;align-items:center;padding:2rem 1rem;user-select:none;">

        ${trial.prompt ? `<div style="margin-bottom:1.25rem;font-size:1.05rem;">${trial.prompt}</div>` : ''}

        <div style="position:relative;width:${trial.image_width}px;touch-action:none;">

          <div id="ind-left" style="
            position:absolute;top:14px;left:14px;z-index:2;pointer-events:none;
            background:rgba(220,38,38,0.88);color:#fff;
            padding:5px 14px;border-radius:20px;
            font-weight:700;font-size:1rem;letter-spacing:0.02em;
            opacity:0;
          ">${trial.left_label}</div>

          <div id="ind-right" style="
            position:absolute;top:14px;right:14px;z-index:2;pointer-events:none;
            background:rgba(22,163,74,0.88);color:#fff;
            padding:5px 14px;border-radius:20px;
            font-weight:700;font-size:1rem;letter-spacing:0.02em;
            opacity:0;
          ">${trial.right_label}</div>

          <img
            id="swipe-img"
            src="${trial.stimulus}"
            draggable="false"
            style="
              display:block;
              width:${trial.image_width}px;
              height:${trial.image_height}px;
              object-fit:cover;
              border-radius:12px;
              box-shadow:0 6px 24px rgba(0,0,0,0.18);
              cursor:grab;
              will-change:transform;
            "
          />
        </div>

        ${trial.show_buttons ? `
          <div style="display:flex;gap:2.5rem;margin-top:1.5rem;">
            <button id="btn-left" class="jspsych-btn" style="min-width:90px;">← ${trial.left_label}</button>
            <button id="btn-right" class="jspsych-btn" style="min-width:90px;">${trial.right_label} →</button>
          </div>` : ''}

        <p style="margin-top:1rem;font-size:0.78rem;opacity:0.4;">
          Swipe or drag left / right${trial.show_buttons ? ', or use the buttons' : ''} · ← → keys also work
        </p>
      </div>
    `;

    const img = displayElement.querySelector('#swipe-img');
    const indLeft = displayElement.querySelector('#ind-left');
    const indRight = displayElement.querySelector('#ind-right');

    // ── Cleanup helpers ──────────────────────────────────────────────────────
    const onMouseMove = (e) => { if (dragStartX !== null) onDragMove(e.clientX); };
    const onMouseUp = () => onDragEnd();

    const cleanup = () => {
      document.removeEventListener('keydown', onKey);
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };

    // ── Respond ──────────────────────────────────────────────────────────────
    const respond = (direction) => {
      if (responded) return;
      responded = true;
      cleanup();

      const flyX = direction === 'right'
        ? `${trial.image_width * 1.6}px`
        : `-${trial.image_width * 1.6}px`;
      const rotate = direction === 'right' ? '28deg' : '-28deg';

      img.style.transition = 'transform 0.35s ease, opacity 0.3s ease';
      img.style.transform = `translateX(${flyX}) rotate(${rotate})`;
      img.style.opacity = '0';

      setTimeout(() => {
        this.jsPsych.finishTrial({
          rt: Math.round(performance.now() - startTime),
          response: direction,
          stimulus: trial.stimulus,
        });
      }, 360);
    };

    // ── Drag (mouse + touch) ─────────────────────────────────────────────────
    let dragStartX = null;
    let dragCurrentX = 0;

    const onDragStart = (x) => {
      dragStartX = x;
      img.style.transition = 'none';
      img.style.cursor = 'grabbing';
    };

    const onDragMove = (x) => {
      if (dragStartX === null) return;
      dragCurrentX = x - dragStartX;
      const rotate = dragCurrentX * 0.07;
      img.style.transform = `translateX(${dragCurrentX}px) rotate(${rotate}deg)`;

      const progress = Math.min(Math.abs(dragCurrentX) / trial.swipe_threshold, 1);
      indLeft.style.opacity = dragCurrentX < 0 ? progress : 0;
      indRight.style.opacity = dragCurrentX > 0 ? progress : 0;
    };

    const onDragEnd = () => {
      if (dragStartX === null) return;
      dragStartX = null;
      img.style.cursor = 'grab';
      indLeft.style.opacity = 0;
      indRight.style.opacity = 0;

      if (Math.abs(dragCurrentX) >= trial.swipe_threshold) {
        respond(dragCurrentX > 0 ? 'right' : 'left');
      } else {
        img.style.transition = 'transform 0.3s ease';
        img.style.transform = 'translateX(0) rotate(0deg)';
      }
      dragCurrentX = 0;
    };

    // Mouse
    img.addEventListener('mousedown', (e) => onDragStart(e.clientX));
    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);

    // Touch
    img.addEventListener('touchstart', (e) => {
      e.preventDefault();
      onDragStart(e.touches[0].clientX);
    }, { passive: false });

    img.addEventListener('touchmove', (e) => {
      e.preventDefault();
      onDragMove(e.touches[0].clientX);
    }, { passive: false });

    img.addEventListener('touchend', () => onDragEnd());

    // Keyboard
    const onKey = (e) => {
      if (e.key === 'ArrowLeft') respond('left');
      if (e.key === 'ArrowRight') respond('right');
    };
    document.addEventListener('keydown', onKey);

    // Buttons
    if (trial.show_buttons) {
      displayElement.querySelector('#btn-left').addEventListener('click', () => respond('left'));
      displayElement.querySelector('#btn-right').addEventListener('click', () => respond('right'));
    }
  }
}
