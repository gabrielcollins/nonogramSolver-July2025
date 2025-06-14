#!/usr/bin/env python3
import argparse
import cv2
import numpy as np
import pytesseract

def extract_row_clues(img_path, n_rows, clue_cols, psm=6):
    # 1) Load & threshold (invert so digits are white on black)
    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise FileNotFoundError(f"Couldn’t load {img_path!r}")
    _, th = cv2.threshold(img, 0, 255,
                          cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)

    # 2) Compute cell dimensions
    h, w = th.shape
    cell_h = h // n_rows
    cell_w = w // clue_cols

    # 3) Remove grid lines
    horiz_k = cv2.getStructuringElement(cv2.MORPH_RECT, (cell_w, 1))
    vert_k  = cv2.getStructuringElement(cv2.MORPH_RECT, (1, cell_h))
    lines_h = cv2.morphologyEx(th, cv2.MORPH_OPEN, horiz_k)
    lines_v = cv2.morphologyEx(th, cv2.MORPH_OPEN, vert_k)
    clean   = cv2.subtract(cv2.subtract(th, lines_h), lines_v)

    # 4) Auto-crop stray bottom pixels so height % n_rows == 0
    h2, w2 = clean.shape
    excess_h = h2 % n_rows
    if excess_h:
        clean = clean[:-excess_h, :]

    # 5) Auto-trim stray right pixels so width % clue_cols == 0
    h3, w3 = clean.shape
    excess_w = w3 % clue_cols
    if excess_w:
        clean = clean[:, :-excess_w]

    # 6) OCR helper
    def read_cell(region):
        # a) Margin-crop 10%
        hh, ww = region.shape
        m = int(min(hh, ww) * 0.1)
        roi = region[m:hh-m, m:ww-m]

        # b) Upsample for clarity
        roi = cv2.resize(roi, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        # c) Re-threshold high-contrast
        _, roi = cv2.threshold(roi, 0, 255,
                               cv2.THRESH_BINARY | cv2.THRESH_OTSU)
        # d) Denoise speckles
        roi = cv2.medianBlur(roi, 3)
        # e) Pad to avoid clipping
        roi = cv2.copyMakeBorder(roi, 5, 5, 5, 5,
                                 cv2.BORDER_CONSTANT, value=0)

        # f) OCR only digits, LSTM engine, single line
        cfg = f"--oem 1 --psm {psm} -c tessedit_char_whitelist=0123456789"
        txt = pytesseract.image_to_string(roi, config=cfg)
        return [int(s) for s in txt.split() if s.isdigit()]

    # 7) Split into rows → into clue_cols → OCR & flatten
    row_clues = []
    rows = np.vsplit(clean, n_rows)
    for row_img in rows:
        cells = np.hsplit(row_img, clue_cols)
        nums = []
        for cell in cells:
            nums.extend(read_cell(cell))
        row_clues.append(nums)

    return row_clues

def main():
    p = argparse.ArgumentParser(
        description="Extract row‐clues from a Nonogram left‐strip image"
    )
    p.add_argument("image",      help="Left‐clue strip PNG")
    p.add_argument("--rows",     type=int, required=True,
                   help="Number of puzzle rows")
    p.add_argument("--clue-cols",type=int, required=True,
                   help="How many clue‐columns wide")
    p.add_argument("--psm",      type=int, default=6,
                   help="Tesseract --psm mode (default: 6)")
    args = p.parse_args()

    rows = extract_row_clues(
        args.image,
        args.rows,
        args.clue_cols,
        args.psm
    )
    print("rowClues =", rows)

if __name__ == "__main__":
    main()