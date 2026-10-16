/**
 * Twixtle - Offline Word Chain Game Engine
 * Tailored for Kobo Clara BW (Carta 1300 E-Ink)
 */

(function () {
  'use strict';

  // -------------------------------------------------------------
  // 1. DICTIONARY & GRAPH ENGINE
  // -------------------------------------------------------------
  const dict = window.TWIXTLE_DICT || {};
  const levels = window.TWIXTLE_LEVELS || [];

  const wordsSet = new Set((dict.wordsPacked || '').split(' '));

  // Build Homophone Map
  const homoMap = new Map();
  if (Array.isArray(dict.homophones)) {
    for (const g of dict.homophones) {
      for (const w of g) {
        const lw = w.toLowerCase();
        let set = homoMap.get(lw);
        if (!set) {
          set = new Set();
          homoMap.set(lw, set);
        }
        for (const other of g) {
          if (other.toLowerCase() !== lw) {
            set.add(other.toLowerCase());
          }
        }
      }
    }
  }

  // Build Compound Map
  const compMap = new Map();
  if (Array.isArray(dict.compounds)) {
    for (const [a, b] of dict.compounds) {
      const al = a.toLowerCase();
      const bl = b.toLowerCase();
      let setA = compMap.get(al);
      if (!setA) {
        setA = new Set();
        compMap.set(al, setA);
      }
      setA.add(bl);
      let setB = compMap.get(bl);
      if (!setB) {
        setB = new Set();
        compMap.set(bl, setB);
      }
      setB.add(al);
    }
  }

  // Build Verb Groups
  const verbGroups = [];
  const verbByWord = new Map();

  function addVerbGroup(forms) {
    const clean = forms
      .filter((x) => x && wordsSet.has(x.toLowerCase()))
      .map((x) => x.toLowerCase());
    const unique = Array.from(new Set(clean));
    if (unique.length >= 2) {
      const idx = verbGroups.length;
      verbGroups.push(new Set(unique));
      for (const w of unique) {
        let g = verbByWord.get(w);
        if (!g) {
          g = new Set();
          verbByWord.set(w, g);
        }
        g.add(idx);
      }
    }
  }

  if (Array.isArray(dict.irregularVerbs)) {
    for (const forms of dict.irregularVerbs) {
      addVerbGroup(forms);
    }
  }

  const VOWELS = new Set(['a', 'e', 'i', 'o', 'u']);
  function shouldDouble(b) {
    if (b.length < 2) return false;
    const last = b[b.length - 1];
    const prev = b[b.length - 2];
    if (VOWELS.has(last) || !VOWELS.has(prev)) return false;
    if (b.length >= 3 && VOWELS.has(b[b.length - 3])) return false;
    if ('wxy'.includes(last)) return false;
    return true;
  }

  if (Array.isArray(dict.regularVerbs)) {
    for (const b of dict.regularVerbs) {
      const forms = [b];
      if (
        b.endsWith('s') ||
        b.endsWith('x') ||
        b.endsWith('z') ||
        b.endsWith('ch') ||
        b.endsWith('sh')
      ) {
        forms.push(b + 'es');
      } else if (b.endsWith('y') && b.length > 1 && !VOWELS.has(b[b.length - 2])) {
        forms.push(b.slice(0, -1) + 'ies');
      } else {
        forms.push(b + 's');
      }

      if (b.endsWith('e')) {
        forms.push(b + 'd');
      } else if (b.endsWith('y') && b.length > 1 && !VOWELS.has(b[b.length - 2])) {
        forms.push(b.slice(0, -1) + 'ied');
      } else if (shouldDouble(b)) {
        forms.push(b + b[b.length - 1] + 'ed');
      } else {
        forms.push(b + 'ed');
      }

      if (b.endsWith('ie')) {
        forms.push(b.slice(0, -2) + 'ying');
      } else if (
        b.endsWith('e') &&
        !b.endsWith('ee') &&
        !b.endsWith('oe') &&
        !b.endsWith('ye')
      ) {
        forms.push(b.slice(0, -1) + 'ing');
      } else if (shouldDouble(b)) {
        forms.push(b + b[b.length - 1] + 'ing');
      } else {
        forms.push(b + 'ing');
      }
      addVerbGroup(forms);
    }
  }

  // -------------------------------------------------------------
  // 2. VALIDATION FUNCTIONS
  // -------------------------------------------------------------
  function isValidWord(w) {
    return wordsSet.has(w.toLowerCase());
  }

  function isAnagram(w1, w2) {
    if (w1.length !== w2.length) return false;
    return w1.split('').sort().join('') === w2.split('').sort().join('');
  }

  function isHomophone(w1, w2) {
    const alts = homoMap.get(w1);
    if (alts && alts.has(w2)) return true;
    for (const suf of ['s', 'ed', 'ing']) {
      if (
        w1.endsWith(suf) &&
        w1.length > suf.length + 1 &&
        w2.endsWith(suf) &&
        w2.length > suf.length + 1
      ) {
        const base1 = w1.slice(0, -suf.length);
        const base2 = w2.slice(0, -suf.length);
        const baseAlts = homoMap.get(base1);
        if (baseAlts && baseAlts.has(base2)) return true;
      }
    }
    return false;
  }

  function isCompound(w1, w2) {
    const alts = compMap.get(w1);
    return !!(alts && alts.has(w2));
  }

  function isVerbForm(w1, w2) {
    const g1 = verbByWord.get(w1);
    const g2 = verbByWord.get(w2);
    if (!g1 || !g2) return false;
    for (const idx of g1) {
      if (g2.has(idx)) return true;
    }
    return false;
  }

  function isValidStep(w1, w2, moveType) {
    w1 = w1.toLowerCase();
    w2 = w2.toLowerCase();
    if (w1 === w2) return false;
    if (!isValidWord(w1) || !isValidWord(w2)) return false;
    switch (moveType) {
      case 'anagram':
        return isAnagram(w1, w2);
      case 'homophone':
        return isHomophone(w1, w2);
      case 'compound':
        return isCompound(w1, w2);
      case 'verb':
        return isVerbForm(w1, w2);
      default:
        return false;
    }
  }

  // -------------------------------------------------------------
  // 3. STORAGE & STATE MANAGEMENT
  // -------------------------------------------------------------
  const Storage = {
    get(key, defaultValue) {
      try {
        const item = localStorage.getItem('twixtle_' + key);
        return item ? JSON.parse(item) : defaultValue;
      } catch (e) {
        return defaultValue;
      }
    },
    set(key, value) {
      try {
        localStorage.setItem('twixtle_' + key, JSON.stringify(value));
      } catch (e) {}
    },
  };

  // State Variables
  let unlockedLevel = Storage.get('unlocked', 1);
  let currentLevelNumber = Storage.get('current', 1);
  let currentPuzzle = null;
  let activeStep = 0; // 0, 1, or 2 (Row 1, 2, or 3)
  let rowInputs = ['', '', ''];
  let revealedMoves = [false, false, false, false];
  let hintsUsed = false;
  let solvedLevelsMap = Storage.get('solved_map', {});

  // -------------------------------------------------------------
  // 4. DOM ELEMENTS
  // -------------------------------------------------------------
  const el = {
    lblLevel: document.getElementById('lbl-level'),
    badgePerfect: document.getElementById('badge-perfect'),
    badgeSolved: document.getElementById('badge-solved'),
    wordStart: document.getElementById('word-start'),
    wordEnd: document.getElementById('word-end'),
    cards: [
      document.getElementById('card-0'),
      document.getElementById('card-1'),
      document.getElementById('card-2'),
    ],
    tiles: [
      document.getElementById('tiles-0'),
      document.getElementById('tiles-1'),
      document.getElementById('tiles-2'),
    ],
    statusIcons: [
      document.getElementById('status-0'),
      document.getElementById('status-1'),
      document.getElementById('status-2'),
    ],
    pills: [
      document.getElementById('pill-0'),
      document.getElementById('pill-1'),
      document.getElementById('pill-2'),
      document.getElementById('pill-3'),
    ],
    pillTexts: [
      document.getElementById('pill-text-0'),
      document.getElementById('pill-text-1'),
      document.getElementById('pill-text-2'),
      document.getElementById('pill-text-3'),
    ],
    message: document.getElementById('game-message'),
    btnPrev: document.getElementById('btn-prev'),
    btnNext: document.getElementById('btn-next'),
    btnReset: document.getElementById('btn-reset'),
    btnRules: document.getElementById('btn-rules'),
    btnLevels: document.getElementById('btn-levels'),
    btnHint: document.getElementById('btn-hint'),
    btnClearRow: document.getElementById('btn-clear-row'),
    btnGiveUp: document.getElementById('btn-giveup'),
    modalLevels: document.getElementById('modal-levels'),
    levelsGrid: document.getElementById('levels-grid'),
    btnCloseLevels: document.getElementById('btn-close-levels'),
    statUnlocked: document.getElementById('stat-unlocked'),
    statSolved: document.getElementById('stat-solved'),
    statPerfect: document.getElementById('stat-perfect'),
    modalRules: document.getElementById('modal-rules'),
    btnCloseRules: document.getElementById('btn-close-rules'),
    btnRulesOk: document.getElementById('btn-rules-ok'),
    modalVictory: document.getElementById('modal-victory'),
    victorySubtitle: document.getElementById('victory-subtitle'),
    victoryChain: document.getElementById('victory-chain'),
    btnVictoryNext: document.getElementById('btn-victory-next'),
    btnVictoryReplay: document.getElementById('btn-victory-replay'),
    modalSolution: document.getElementById('modal-solution'),
    solutionDisplay: document.getElementById('solution-display'),
    btnCloseSolution: document.getElementById('btn-close-solution'),
    btnConfirmSolution: document.getElementById('btn-confirm-solution'),
    btnCancelSolution: document.getElementById('btn-cancel-solution'),
    keyboard: document.getElementById('virtual-keyboard'),
  };

  // -------------------------------------------------------------
  // 5. GAME LOGIC & RENDERING
  // -------------------------------------------------------------
  function loadLevel(levelNum) {
    if (levelNum < 1) levelNum = 1;
    if (levelNum > levels.length) levelNum = levels.length;

    currentLevelNumber = levelNum;
    Storage.set('current', currentLevelNumber);

    currentPuzzle = levels[currentLevelNumber - 1];
    activeStep = 0;

    // Check for saved state or initialize
    const saved = Storage.get('state_' + currentLevelNumber, null);
    if (saved) {
      rowInputs = saved.rowInputs || ['', '', ''];
      revealedMoves = saved.revealedMoves || [false, false, false, false];
      hintsUsed = !!saved.hintsUsed;
    } else {
      rowInputs = ['', '', ''];
      revealedMoves = [false, false, false, false];
      hintsUsed = false;
    }

    renderBoard();
    clearMessage();
  }

  function saveCurrentState() {
    Storage.set('state_' + currentLevelNumber, {
      rowInputs: rowInputs,
      revealedMoves: revealedMoves,
      hintsUsed: hintsUsed,
    });
  }

  function showMessage(msg, isError = false) {
    el.message.textContent = msg;
    if (isError) {
      el.message.classList.add('error');
    } else {
      el.message.classList.remove('error');
    }
  }

  function clearMessage() {
    el.message.textContent = '';
    el.message.classList.remove('error');
  }

  function renderBoard() {
    if (!currentPuzzle) return;

    el.lblLevel.textContent = currentLevelNumber;
    el.wordStart.textContent = currentPuzzle.start.toUpperCase();
    el.wordEnd.textContent = currentPuzzle.end.toUpperCase();

    // Check level solved status
    const solvedData = solvedLevelsMap[currentLevelNumber];
    if (solvedData) {
      el.badgeSolved.classList.add('visible');
      if (solvedData.perfect) {
        el.badgePerfect.classList.add('visible');
      } else {
        el.badgePerfect.classList.remove('visible');
      }
    } else {
      el.badgeSolved.classList.remove('visible');
      el.badgePerfect.classList.remove('visible');
    }

    // Prev/Next buttons state
    el.btnPrev.disabled = currentLevelNumber <= 1;
    el.btnNext.disabled = currentLevelNumber >= unlockedLevel && !solvedData;

    // Render Connector Move Pills
    for (let i = 0; i < 4; i++) {
      const moveType = currentPuzzle.moves[i];
      if (revealedMoves[i]) {
        el.pills[i].classList.add('revealed');
        el.pills[i].querySelector('.pill-icon').textContent = '•';
        el.pillTexts[i].textContent = moveType.toUpperCase();
      } else {
        el.pills[i].classList.remove('revealed');
        el.pills[i].querySelector('.pill-icon').textContent = '?';
        el.pillTexts[i].textContent = 'REVEAL MOVE';
      }
    }

    // Step validations
    const val0 = isValidStep(currentPuzzle.start, rowInputs[0], currentPuzzle.moves[0]);
    const val1 = val0 && isValidStep(rowInputs[0], rowInputs[1], currentPuzzle.moves[1]);
    const val2 = val1 && isValidStep(rowInputs[1], rowInputs[2], currentPuzzle.moves[2]);
    const val3 = val2 && isValidStep(rowInputs[2], currentPuzzle.end, currentPuzzle.moves[3]);

    const stepValid = [val0, val1, val2];

    // Render Cards and Tiles
    for (let i = 0; i < 3; i++) {
      const card = el.cards[i];
      const container = el.tiles[i];
      const statusIcon = el.statusIcons[i];
      const text = rowInputs[i];

      // Active state
      if (i === activeStep) {
        card.classList.add('active');
      } else {
        card.classList.remove('active');
      }

      // Status
      statusIcon.classList.remove('success', 'failure');
      if (text.length > 0) {
        if (stepValid[i]) {
          statusIcon.classList.add('success');
          card.classList.add('valid');
          card.classList.remove('invalid');
        } else {
          statusIcon.classList.add('failure');
          card.classList.add('invalid');
          card.classList.remove('valid');
        }
      } else {
        card.classList.remove('valid', 'invalid');
      }

      // Render letter tiles
      container.innerHTML = '';
      if (text.length === 0) {
        if (i === activeStep) {
          const cur = document.createElement('span');
          cur.className = 'letter-tile cursor';
          cur.textContent = '';
          container.appendChild(cur);
        } else {
          const ph = document.createElement('span');
          ph.className = 'placeholder-text';
          ph.textContent = 'Tap to type word ' + (i + 1);
          container.appendChild(ph);
        }
      } else {
        for (let c = 0; c < text.length; c++) {
          const tile = document.createElement('span');
          tile.className = 'letter-tile';
          tile.textContent = text[c].toUpperCase();
          container.appendChild(tile);
        }
        if (i === activeStep) {
          const cur = document.createElement('span');
          cur.className = 'letter-tile cursor';
          cur.textContent = '';
          container.appendChild(cur);
        }
      }
    }

    // Check if fully solved
    if (val0 && val1 && val2 && val3) {
      handleVictory();
    }
  }

  function handleKeyPress(key) {
    if (key === 'BACKSPACE') {
      if (rowInputs[activeStep].length > 0) {
        rowInputs[activeStep] = rowInputs[activeStep].slice(0, -1);
        renderBoard();
        clearMessage();
        saveCurrentState();
      }
      return;
    }

    if (key === 'ENTER') {
      checkCurrentStep();
      return;
    }

    // Character key (A-Z)
    if (/^[A-Z]$/.test(key)) {
      if (rowInputs[activeStep].length < 15) {
        rowInputs[activeStep] += key.toLowerCase();
        renderBoard();
        clearMessage();
        saveCurrentState();
      }
    }
  }

  function checkCurrentStep() {
    const input = rowInputs[activeStep].trim().toLowerCase();
    if (!input) {
      showMessage('Please type a word first.', true);
      return;
    }

    if (!isValidWord(input)) {
      showMessage(`"${input.toUpperCase()}" is not in dictionary.`, true);
      return;
    }

    // Validate step by step
    if (activeStep === 0) {
      const ok = isValidStep(currentPuzzle.start, input, currentPuzzle.moves[0]);
      if (ok) {
        showMessage(`Valid ${currentPuzzle.moves[0].toUpperCase()}!`);
        activeStep = 1;
        renderBoard();
        saveCurrentState();
      } else {
        const m = currentPuzzle.moves[0].toUpperCase();
        showMessage(`"${input.toUpperCase()}" is not a valid ${m} of ${currentPuzzle.start.toUpperCase()}.`, true);
      }
      return;
    }

    if (activeStep === 1) {
      const prev = rowInputs[0].trim().toLowerCase();
      if (!isValidStep(currentPuzzle.start, prev, currentPuzzle.moves[0])) {
        showMessage(`Solve Word 1 first.`, true);
        activeStep = 0;
        renderBoard();
        return;
      }
      const ok = isValidStep(prev, input, currentPuzzle.moves[1]);
      if (ok) {
        showMessage(`Valid ${currentPuzzle.moves[1].toUpperCase()}!`);
        activeStep = 2;
        renderBoard();
        saveCurrentState();
      } else {
        const m = currentPuzzle.moves[1].toUpperCase();
        showMessage(`"${input.toUpperCase()}" is not a valid ${m} of ${prev.toUpperCase()}.`, true);
      }
      return;
    }

    if (activeStep === 2) {
      const prev = rowInputs[1].trim().toLowerCase();
      if (!isValidStep(rowInputs[0], prev, currentPuzzle.moves[1])) {
        showMessage(`Solve Word 2 first.`, true);
        activeStep = 1;
        renderBoard();
        return;
      }
      const ok3 = isValidStep(prev, input, currentPuzzle.moves[2]);
      if (!ok3) {
        const m = currentPuzzle.moves[2].toUpperCase();
        showMessage(`"${input.toUpperCase()}" is not a valid ${m} of ${prev.toUpperCase()}.`, true);
        return;
      }
      // Check final connection to end word!
      const ok4 = isValidStep(input, currentPuzzle.end, currentPuzzle.moves[3]);
      if (!ok4) {
        const m = currentPuzzle.moves[3].toUpperCase();
        showMessage(
          `Valid ${currentPuzzle.moves[2].toUpperCase()}, but doesn't lead to ${currentPuzzle.end.toUpperCase()} via ${m}.`,
          true
        );
        renderBoard();
        saveCurrentState();
        return;
      }

      // Complete puzzle!
      renderBoard();
      saveCurrentState();
    }
  }

  function handleVictory() {
    const isPerfect = !hintsUsed && revealedMoves.every((r) => !r);

    solvedLevelsMap[currentLevelNumber] = {
      solved: true,
      perfect: isPerfect,
      date: new Date().toISOString(),
    };
    Storage.set('solved_map', solvedLevelsMap);

    // Unlock next level
    if (currentLevelNumber >= unlockedLevel && unlockedLevel < levels.length) {
      unlockedLevel = currentLevelNumber + 1;
      Storage.set('unlocked', unlockedLevel);
    }

    // Build victory chain modal
    el.victoryChain.innerHTML = '';
    const words = [
      currentPuzzle.start,
      rowInputs[0],
      rowInputs[1],
      rowInputs[2],
      currentPuzzle.end,
    ];

    for (let i = 0; i < 4; i++) {
      const stepDiv = document.createElement('div');
      stepDiv.className = 'victory-step';

      const left = document.createElement('span');
      left.className = 'victory-step-word';
      left.textContent = words[i].toUpperCase() + ' ➔ ' + words[i + 1].toUpperCase();

      const right = document.createElement('span');
      right.className = 'victory-step-move';
      right.textContent = currentPuzzle.moves[i].toUpperCase();

      stepDiv.appendChild(left);
      stepDiv.appendChild(right);
      el.victoryChain.appendChild(stepDiv);
    }

    if (isPerfect) {
      el.victorySubtitle.textContent = '★ PERFECT SOLVE! No hints used.';
    } else {
      el.victorySubtitle.textContent = '✓ Level Solved!';
    }

    el.modalVictory.classList.remove('hidden');
  }

  // -------------------------------------------------------------
  // 6. EVENT LISTENERS & MODALS
  // -------------------------------------------------------------
  // Keyboard Clicks
  document.querySelectorAll('.kb-key').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const key = btn.getAttribute('data-key');
      handleKeyPress(key);
    });
  });

  // Physical keyboard support
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Backspace') {
      handleKeyPress('BACKSPACE');
      e.preventDefault();
    } else if (e.key === 'Enter') {
      handleKeyPress('ENTER');
      e.preventDefault();
    } else if (e.key === 'Escape') {
      closeAllModals();
      e.preventDefault();
    } else if (/^[a-zA-Z]$/.test(e.key)) {
      handleKeyPress(e.key.toUpperCase());
    }
  });

  // Word Card taps
  el.cards.forEach((card, idx) => {
    card.addEventListener('click', () => {
      activeStep = idx;
      renderBoard();
      clearMessage();
    });
  });

  // Reveal Move Pills
  el.pills.forEach((pill, idx) => {
    pill.addEventListener('click', () => {
      if (!revealedMoves[idx]) {
        revealedMoves[idx] = true;
        hintsUsed = true;
        renderBoard();
        saveCurrentState();
        showMessage(`Move ${idx + 1} revealed: ${currentPuzzle.moves[idx].toUpperCase()}`);
      }
    });
  });

  // Action Buttons
  el.btnHint.addEventListener('click', () => {
    hintsUsed = true;
    const targetWord = currentPuzzle.solution[activeStep + 1];
    const curr = rowInputs[activeStep];
    if (curr.length < targetWord.length) {
      rowInputs[activeStep] = targetWord.slice(0, curr.length + 1);
    } else {
      rowInputs[activeStep] = targetWord;
    }
    renderBoard();
    saveCurrentState();
    showMessage(`Hint: Word ${activeStep + 1} begins with "${rowInputs[activeStep].toUpperCase()}"`);
  });

  el.btnClearRow.addEventListener('click', () => {
    rowInputs[activeStep] = '';
    renderBoard();
    saveCurrentState();
    clearMessage();
  });

  el.btnReset.addEventListener('click', () => {
    rowInputs = ['', '', ''];
    revealedMoves = [false, false, false, false];
    hintsUsed = false;
    activeStep = 0;
    renderBoard();
    saveCurrentState();
    showMessage('Level reset.');
  });

  el.btnPrev.addEventListener('click', () => {
    if (currentLevelNumber > 1) {
      loadLevel(currentLevelNumber - 1);
    }
  });

  el.btnNext.addEventListener('click', () => {
    if (currentLevelNumber < unlockedLevel || solvedLevelsMap[currentLevelNumber]) {
      loadLevel(currentLevelNumber + 1);
    }
  });

  // Rules Modal
  el.btnRules.addEventListener('click', () => {
    el.modalRules.classList.remove('hidden');
  });
  el.btnCloseRules.addEventListener('click', () => {
    el.modalRules.classList.add('hidden');
  });
  el.btnRulesOk.addEventListener('click', () => {
    el.modalRules.classList.add('hidden');
  });

  // Levels Select Modal
  el.btnLevels.addEventListener('click', () => {
    openLevelsModal();
  });
  el.btnCloseLevels.addEventListener('click', () => {
    el.modalLevels.classList.add('hidden');
  });

  function openLevelsModal(filter = 'all') {
    const maxEl = document.getElementById('max-level-count');
    if (maxEl) maxEl.textContent = levels.length;
    el.statUnlocked.textContent = unlockedLevel;

    let solvedCount = 0;
    let perfectCount = 0;
    for (const k in solvedLevelsMap) {
      if (solvedLevelsMap[k].solved) solvedCount++;
      if (solvedLevelsMap[k].perfect) perfectCount++;
    }
    el.statSolved.textContent = solvedCount;
    el.statPerfect.textContent = perfectCount;

    renderLevelsGrid(filter);
    el.modalLevels.classList.remove('hidden');
  }

  function renderLevelsGrid(filter) {
    el.levelsGrid.innerHTML = '';

    for (let i = 1; i <= levels.length; i++) {
      const isUnlocked = i <= unlockedLevel;
      const solvedData = solvedLevelsMap[i];
      const isSolved = !!solvedData;

      if (filter === 'solved' && !isSolved) continue;
      if (filter === 'unsolved' && isSolved) continue;

      const btn = document.createElement('button');
      btn.className = 'level-btn';
      if (i === currentLevelNumber) btn.classList.add('active');

      if (!isUnlocked) {
        btn.classList.add('locked');
        btn.textContent = '🔒 ' + i;
        btn.disabled = true;
      } else if (isSolved) {
        btn.classList.add('solved');
        btn.textContent = '✓ ' + i;
        if (solvedData.perfect) {
          const star = document.createElement('span');
          star.className = 'level-btn-star';
          star.textContent = '★';
          btn.appendChild(star);
        }
      } else {
        btn.textContent = i;
      }

      if (isUnlocked) {
        btn.addEventListener('click', () => {
          el.modalLevels.classList.add('hidden');
          loadLevel(i);
        });
      }

      el.levelsGrid.appendChild(btn);
    }
  }

  document.querySelectorAll('.btn-filter').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.btn-filter').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      renderLevelsGrid(btn.getAttribute('data-filter'));
    });
  });

  // Victory Modal Actions
  el.btnVictoryNext.addEventListener('click', () => {
    el.modalVictory.classList.add('hidden');
    loadLevel(currentLevelNumber + 1);
  });
  el.btnVictoryReplay.addEventListener('click', () => {
    el.modalVictory.classList.add('hidden');
    loadLevel(currentLevelNumber);
  });

  // Give Up / Solution Modal
  el.btnGiveUp.addEventListener('click', () => {
    el.solutionDisplay.classList.add('hidden');
    el.solutionDisplay.innerHTML = '';
    el.btnConfirmSolution.classList.remove('hidden');
    el.modalSolution.classList.remove('hidden');
  });
  el.btnCloseSolution.addEventListener('click', () => {
    el.modalSolution.classList.add('hidden');
  });
  el.btnCancelSolution.addEventListener('click', () => {
    el.modalSolution.classList.add('hidden');
  });
  el.btnConfirmSolution.addEventListener('click', () => {
    hintsUsed = true;
    revealedMoves = [true, true, true, true];
    rowInputs = [
      currentPuzzle.solution[1],
      currentPuzzle.solution[2],
      currentPuzzle.solution[3],
    ];
    saveCurrentState();

    // Display chain
    const chainDiv = document.createElement('div');
    chainDiv.className = 'solution-chain';
    for (let i = 0; i < 4; i++) {
      const row = document.createElement('div');
      row.textContent = `${currentPuzzle.solution[i].toUpperCase()} ➔ ${currentPuzzle.solution[i + 1].toUpperCase()} (${currentPuzzle.moves[i].toUpperCase()})`;
      chainDiv.appendChild(row);
    }
    el.solutionDisplay.innerHTML = '';
    el.solutionDisplay.appendChild(chainDiv);
    el.solutionDisplay.classList.remove('hidden');
    el.btnConfirmSolution.classList.add('hidden');

    renderBoard();
  });

  function closeAllModals() {
    el.modalLevels.classList.add('hidden');
    el.modalRules.classList.add('hidden');
    el.modalVictory.classList.add('hidden');
    el.modalSolution.classList.add('hidden');
  }

  // -------------------------------------------------------------
  // 7. INITIALIZATION
  // -------------------------------------------------------------
  loadLevel(currentLevelNumber);
})();
