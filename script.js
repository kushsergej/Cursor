// Minesweeper configuration
const ROWS = 9;
const COLS = 9;
const MINES = 10;

let board = [];
let revealed = [];
let flagged = [];
let gameOver = false;
let cellsRevealed = 0;

const root = document.getElementById('minesweeper-root');

function initGame() {
    board = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
    revealed = Array.from({ length: ROWS }, () => Array(COLS).fill(false));
    flagged = Array.from({ length: ROWS }, () => Array(COLS).fill(false));
    gameOver = false;
    cellsRevealed = 0;
    placeMines();
    calculateNumbers();
    render();
}

function placeMines() {
    let minesPlaced = 0;
    while (minesPlaced < MINES) {
        const r = Math.floor(Math.random() * ROWS);
        const c = Math.floor(Math.random() * COLS);
        if (board[r][c] !== 'M') {
            board[r][c] = 'M';
            minesPlaced++;
        }
    }
}

function calculateNumbers() {
    for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
            if (board[r][c] === 'M') continue;
            let count = 0;
            for (let dr = -1; dr <= 1; dr++) {
                for (let dc = -1; dc <= 1; dc++) {
                    if (dr === 0 && dc === 0) continue;
                    const nr = r + dr, nc = c + dc;
                    if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && board[nr][nc] === 'M') {
                        count++;
                    }
                }
            }
            board[r][c] = count;
        }
    }
}

function render() {
    root.innerHTML = '';
    const status = document.createElement('div');
    status.className = 'status';
    if (gameOver) {
        status.textContent = cellsRevealed === ROWS * COLS - MINES ? 'You Win! 🎉' : 'Game Over! 💣';
    } else {
        status.textContent = 'Minesweeper';
    }
    root.appendChild(status);

    const boardDiv = document.createElement('div');
    boardDiv.className = 'board';
    boardDiv.style.gridTemplateRows = `repeat(${ROWS}, 1fr)`;
    boardDiv.style.gridTemplateColumns = `repeat(${COLS}, 1fr)`;

    for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
            const cell = document.createElement('div');
            cell.className = 'cell';
            if (revealed[r][c]) {
                cell.classList.add('revealed');
                if (board[r][c] === 'M') {
                    cell.classList.add('mine');
                    cell.textContent = '💣';
                } else if (board[r][c] > 0) {
                    cell.textContent = board[r][c];
                }
            } else if (flagged[r][c]) {
                cell.classList.add('flagged');
                cell.textContent = '🚩';
            }
            cell.addEventListener('click', (e) => {
                if (gameOver) return;
                if (e.button === 0) handleReveal(r, c);
            });
            cell.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                if (gameOver) return;
                handleFlag(r, c);
            });
            boardDiv.appendChild(cell);
        }
    }
    root.appendChild(boardDiv);

    const resetBtn = document.createElement('button');
    resetBtn.textContent = 'Restart';
    resetBtn.onclick = initGame;
    root.appendChild(resetBtn);
}

function handleReveal(r, c) {
    if (revealed[r][c] || flagged[r][c]) return;
    revealed[r][c] = true;
    cellsRevealed++;
    if (board[r][c] === 'M') {
        gameOver = true;
        revealAllMines();
    } else if (board[r][c] === 0) {
        revealAdjacent(r, c);
    }
    if (cellsRevealed === ROWS * COLS - MINES) {
        gameOver = true;
    }
    render();
}

function handleFlag(r, c) {
    if (revealed[r][c]) return;
    flagged[r][c] = !flagged[r][c];
    render();
}

function revealAdjacent(r, c) {
    for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
            const nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < ROWS && nc >= 0 && nc < COLS && !revealed[nr][nc] && board[nr][nc] !== 'M') {
                revealed[nr][nc] = true;
                cellsRevealed++;
                if (board[nr][nc] === 0) {
                    revealAdjacent(nr, nc);
                }
            }
        }
    }
}

function revealAllMines() {
    for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
            if (board[r][c] === 'M') {
                revealed[r][c] = true;
            }
        }
    }
}

window.onload = initGame; 