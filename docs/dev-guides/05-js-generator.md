# JsGenerator — Full Transformation Examples

`Socho.Studies.JsGenerator` walks a tree of `Trial` nodes and produces the JS
and CSS assets that power a jsPsych experiment page. This guide shows the exact
input and output for every node type so you can trace the transformation end-to-end.

The public entry points are `required_stylesheets/1`, `required_scripts/1`, and
`generate_inline_js/1`. All three accept any map with a `trials` key — no
database connection required.

The boilerplate at the top of every `generate_inline_js/1` output (the
`saveData` function and `initJsPsych` call) is the same in all examples and is
shown in full only in the first one. Subsequent examples replace it with `# ...`.

---

## 1. Regular trial (`node_type: "trial"`)

A leaf node. Each trial emits a single `const trial{n}` declaration.

### Input

```elixir
study = %{
  trials: [
    %Trial{
      node_type: "trial",
      plugin: "html-keyboard-response",
      config: %{"stimulus" => "<p>Press F or J</p>", "choices" => ["f", "j"]},
      extensions: %{},
      children: []
    }
  ]
}
```

### `required_stylesheets/1`

```elixir
JsGenerator.required_stylesheets(study)
#=> ["/vendor/jspsych/jspsych.css"]
```

### `required_scripts/1`

```elixir
JsGenerator.required_scripts(study)
#=> ["/vendor/jspsych/jspsych.js",
#    "/vendor/jspsych/html-keyboard-response.js"]
```

### `generate_inline_js/1`

```javascript
const __preview__ = new URLSearchParams(window.location.search).has('preview');

function saveData(trialData) {
  if (__preview__) {
    document.body.innerHTML = [
      "<div style='display:flex;flex-direction:column;align-items:center;justify-content:center;",
      "height:100vh;font-family:sans-serif;gap:1rem;padding:2rem;text-align:center'>",
      "<p style='font-size:1.2rem'>✓ Preview complete</p>",
      "<button onclick='location.reload()' ",
      "style='padding:8px 20px;border:1px solid #ccc;border-radius:6px;cursor:pointer;background:#fff'>",
      "↺ Restart preview</button></div>"
    ].join('');
    return;
  }
  const csrfToken = document.querySelector('meta[name="csrf-token"]').content;
  fetch(window.location.pathname + "/user-data", {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrfToken },
    body: JSON.stringify({ data: trialData })
  })
    .then(r => r.json())
    .then(result => {
      if (result.status === "already_submitted") {
        document.body.innerHTML = "<div style='display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif'><p>You have already completed this study. Thank you!</p></div>";
      }
    })
    .catch(err => console.error("Failed to save data:", err));
}

const jsPsych = initJsPsych({
  on_finish: function() { saveData(jsPsych.data.get().values()); }
});

const trial1 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Press F or J</p>`,
  choices: [`f`, `j`],
};

jsPsych.run([trial1]);
```

---

## 2. Timeline (`node_type: "timeline"`)

A container node that wraps children in a jsPsych timeline object. Supports
`repetitions`, `randomize_order`, `timeline_variables`, and conditional/loop
functions via `config`.

The emitter assigns the container the current counter (`timeline1`) and starts
child numbering from `counter + 1`. Child declarations are emitted **before**
the container declaration so that variable references resolve correctly.

### Input

```elixir
study = %{
  trials: [
    %Trial{
      node_type: "timeline",
      plugin: nil,
      config: %{"repetitions" => 2},
      extensions: %{},
      children: [
        %Trial{
          node_type: "trial",
          plugin: "image-keyboard-response",
          config: %{"stimulus" => "cat.jpg", "choices" => ["f", "j"]},
          extensions: %{},
          children: []
        },
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Done</p>"},
          extensions: %{},
          children: []
        }
      ]
    }
  ]
}
```

### `required_scripts/1`

```elixir
JsGenerator.required_scripts(study)
#=> ["/vendor/jspsych/jspsych.js",
#    "/vendor/jspsych/image-keyboard-response.js",
#    "/vendor/jspsych/html-keyboard-response.js"]
```

### `generate_inline_js/1`

```javascript
// ...boilerplate...

const trial2 = {
  type: jsPsychImageKeyboardResponse,
  stimulus: `cat.jpg`,
  choices: [`f`, `j`],
};

const trial3 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Done</p>`,
};

const timeline1 = {
  timeline: [trial2, trial3],
  repetitions: 2,
};

jsPsych.run([timeline1]);
```

Notice that `timeline1` is declared **after** its children even though it holds
counter `1`. The counter reserves the name upfront; child emission happens
recursively starting at `counter + 1`.

---

## 3. Template group (`node_type: "template_group"`)

Identical to a timeline in structure but carries no extra config. Used by the
study builder's template system to group a preset block of trials together.

The only output difference from a plain timeline is that the `timeline` array
has no trailing comma (no config fields follow it).

### Input

```elixir
study = %{
  trials: [
    %Trial{
      node_type: "template_group",
      plugin: nil,
      config: %{},
      extensions: %{},
      children: [
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Instructions: press F or J</p>"},
          extensions: %{},
          children: []
        },
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>All done!</p>"},
          extensions: %{},
          children: []
        }
      ]
    }
  ]
}
```

### `generate_inline_js/1`

```javascript
// ...boilerplate...

const trial2 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Instructions: press F or J</p>`,
};

const trial3 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>All done!</p>`,
};

const timeline1 = {
  timeline: [trial2, trial3]
};

jsPsych.run([timeline1]);
```

---

## 4. Counterbalanced group (`node_type: "counterbalanced_group"`)

Splits children into groups and randomly selects one group at runtime. This
counterbalances trial order across participants without any server-side
coordination.

By default the children are split evenly in half. The `group_sizes` config key
overrides this with an explicit list of sizes (one integer per group).

### Input — default even split

Four children, no `group_sizes`: split at index `div(4, 2) = 2`, producing two
groups of two.

```elixir
study = %{
  trials: [
    %Trial{
      node_type: "counterbalanced_group",
      plugin: nil,
      config: %{},
      extensions: %{},
      children: [
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Version A — Trial 1</p>"},
          extensions: %{},
          children: []
        },
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Version A — Trial 2</p>"},
          extensions: %{},
          children: []
        },
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Version B — Trial 1</p>"},
          extensions: %{},
          children: []
        },
        %Trial{
          node_type: "trial",
          plugin: "html-keyboard-response",
          config: %{"stimulus" => "<p>Version B — Trial 2</p>"},
          extensions: %{},
          children: []
        }
      ]
    }
  ]
}
```

### `generate_inline_js/1`

```javascript
// ...boilerplate...

const trial2 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Version A — Trial 1</p>`,
};

const trial3 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Version A — Trial 2</p>`,
};

const trial4 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Version B — Trial 1</p>`,
};

const trial5 = {
  type: jsPsychHtmlKeyboardResponse,
  stimulus: `<p>Version B — Trial 2</p>`,
};

const timeline1 = (function() {
  const versions = [
    [trial2, trial3],
    [trial4, trial5]
  ];
  return { timeline: versions[Math.floor(Math.random() * versions.length)] };
})();

jsPsych.run([timeline1]);
```

### `group_sizes` override

To split three children into groups of 1 and 2, set `config: %{"group_sizes" => [1, 2]}`.
The emitter slices children sequentially — first group gets 1 child, second gets 2.

---

## 5. Pairwise compare (`plugin: "pairwise-compare"`)

A synthetic plugin type. Rather than mapping directly to a jsPsych plugin, it
expands into an IIFE that shuffles the image list, pairs them up, and runs each
pair as a `jsPsychMultiImageSelect` trial via `timeline_variables`.

The emitted variable is always named `timeline{n}` (not `trial{n}`) because the
output is a timeline object, not a single trial.

### Input

```elixir
study = %{
  trials: [
    %Trial{
      node_type: "trial",
      plugin: "pairwise-compare",
      config: %{
        "images"    => ["cat.jpg", "dog.jpg", "bird.jpg", "fish.jpg"],
        "prompt"    => "Which animal do you prefer?",
        "data_tag"  => "pairwise_round",
        "image_width"  => 300,
        "image_height" => 300
      },
      extensions: %{},
      children: []
    }
  ]
}
```

### `required_scripts/1`

```elixir
JsGenerator.required_scripts(study)
#=> ["/vendor/jspsych/jspsych.js",
#    "/vendor/jspsych/multi-image-select.js"]
```

`collect_plugins/1` maps `"pairwise-compare"` to `"multi-image-select"`, so
the correct script is requested even though the plugin name in the config is
`"pairwise-compare"`.

### `generate_inline_js/1`

```javascript
// ...boilerplate...

const timeline1 = (function() {
  var _images = ["cat.jpg","dog.jpg","bird.jpg","fish.jpg"];
  var _shuffled = jsPsych.randomization.shuffle(_images.slice());
  var _pairs = [];
  for (var i = 0; i + 1 < _shuffled.length; i += 2) {
    _pairs.push({ _pw_images: [_shuffled[i], _shuffled[i + 1]] });
  }
  return {
    timeline: [{
      type: jsPsychMultiImageSelect,
      images: jsPsych.timelineVariable('_pw_images'),
      columns: 2,
      image_width: 300,
      image_height: 300,
      prompt: `Which animal do you prefer?`,
      data: { data_tag: `pairwise_round` },
    }],
    timeline_variables: _pairs,
  };
})();

jsPsych.run([timeline1]);
```

The shuffle happens once when the page loads. Odd-length image lists result in
the last image being dropped (the `i + 1 < length` loop condition).
