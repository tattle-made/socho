import { ParameterType } from '../types.js';

export default class MultipleImages {
  static info = {
    name: 'multiple-images',
    version: '1.0.0',
    description: 'Shows a configurable grid of images with a free-text response box.',
    parameters: {
      images: {
        type: ParameterType.IMAGE,
        default: undefined,
        array: true,
        description: 'Array of image URLs to display in the grid.',
      },
      prompt: {
        type: ParameterType.HTML_STRING,
        default: null,
        array: false,
        description: 'Instructions or question shown above the image grid (HTML allowed).',
      },
      placeholder: {
        type: ParameterType.STRING,
        default: 'Enter your response...',
        array: false,
        description: 'Placeholder text for the response box.',
      },
      button_label: {
        type: ParameterType.STRING,
        default: 'Continue',
        array: false,
        description: 'Label for the submit button.',
      },
      required: {
        type: ParameterType.BOOL,
        default: false,
        array: false,
        description: 'If true, participant must enter text before continuing.',
      },
      columns: {
        type: ParameterType.INT,
        default: 3,
        array: false,
        description: 'Number of grid columns. Set to 0 for auto-fit based on image_width.',
      },
      image_width: {
        type: ParameterType.INT,
        default: 240,
        array: false,
        description: 'Width of each image in pixels (also used as min-width for auto-fit).',
      },
      image_height: {
        type: ParameterType.INT,
        default: 180,
        array: false,
        description: 'Height of each image in pixels.',
      },
    },
  };

  constructor(jsPsych) {
    this.jsPsych = jsPsych;
  }

  trial(displayElement, trial) {
    const startTime = performance.now();
    const images = trial.images || [];

    const gridColumns =
      trial.columns > 0
        ? `repeat(${trial.columns}, 1fr)`
        : `repeat(auto-fill, minmax(${trial.image_width}px, 1fr))`;

    const imageHTML = images
      .map(
        src => `
        <div style="overflow:hidden;border-radius:6px;background:#f0f0f0;">
          <img
            src="${src}"
            style="width:100%;height:${trial.image_height}px;object-fit:cover;display:block;"
            alt=""
          />
        </div>`
      )
      .join('');

    displayElement.innerHTML = `
      <div style="max-width:900px;margin:0 auto;padding:2rem 1.5rem;">
        ${trial.prompt ? `<div style="margin-bottom:1.25rem;font-size:1.05rem;">${trial.prompt}</div>` : ''}

        <div style="
          display:grid;
          grid-template-columns:${gridColumns};
          gap:12px;
          margin-bottom:1.5rem;
        ">
          ${imageHTML}
        </div>

        <textarea
          id="mi-response"
          placeholder="${trial.placeholder}"
          rows="4"
          style="
            width:100%;
            padding:10px 12px;
            font-size:1rem;
            border:1px solid #ccc;
            border-radius:6px;
            resize:vertical;
            box-sizing:border-box;
            font-family:inherit;
          "
        ></textarea>

        <div style="text-align:center;margin-top:1rem;">
          <button id="mi-btn" class="jspsych-btn">${trial.button_label}</button>
        </div>
      </div>
    `;

    const textarea = displayElement.querySelector('#mi-response');
    const btn = displayElement.querySelector('#mi-btn');

    btn.addEventListener('click', () => {
      const response = textarea.value.trim();

      if (trial.required && response === '') {
        textarea.style.borderColor = '#e53e3e';
        textarea.style.outline = '2px solid #fed7d7';
        textarea.focus();
        return;
      }

      this.jsPsych.finishTrial({
        rt: Math.round(performance.now() - startTime),
        response,
        images: trial.images,
        num_images: images.length,
      });
    });
  }
}
