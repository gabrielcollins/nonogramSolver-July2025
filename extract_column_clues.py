#!/usr/bin/env python3
import argparse
import cv2
import numpy as np
import pytesseract

def extract_column_clues(img_path, n_cols, clue_rows, psm=6):
    # 1. Load & binarize+invert
    img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise FileNotFoundError(f"Couldn’t load {img_path!r}")
    _, th = cv2.threshold(img, 0, 255,
                          cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)

    # 2. Compute cell size (used for line-removal kernels)
    h, w = th.shape
    cell_w = w // n_cols
    cell_h = h // clue_rows

    # 3. Remove grid‐lines
    horiz_k = cv2.getStructuringElement(cv2.MORPH_RECT, (cell_w, 1))
    vert_k  = cv2.getStructuringElement(cv2.MORPH_RECT, (1, cell_h))
    lines_h = cv2.morphologyEx(th, cv2.MORPH_OPEN, horiz_k)
    lines_v = cv2.morphologyEx(th, cv2.MORPH_OPEN, vert_k)
    clean   = cv2.subtract(cv2.subtract(th, lines_h), lines_v)

    # 4. AUTO‐CROP stray bottom pixels so height % clue_rows == 0
    h2, w2 = clean.shape
    excess_h = h2 % clue_rows
    if excess_h:
        clean = clean[:-excess_h, :]

    # 5. AUTO‐TRIM stray right‐edge pixels so width % n_cols == 0
    h3, w3 = clean.shape
    excess_w = w3 % n_cols
    if excess_w:
        clean = clean[:, :-excess_w]

    # 6. OCR helper for one cell
    def read_cell(region):
        h0, w0 = region.shape
        m = int(min(h0, w0) * 0.1)
        roi = region[m:h0-m, m:w0-m]
        roi = cv2.copyMakeBorder(roi, 5,5,5,5, cv2.BORDER_CONSTANT, value=0)
        cfg = f"--psm {psm} -c tessedit_char_whitelist=0123456789"
        txt = pytesseract.image_to_string(roi, config=cfg)
        return [int(s) for s in txt.split() if s.isdigit()]

    # 7. Split into columns, then into clue_rows, OCR & flatten
    column_clues = []
    cols = np.hsplit(clean, n_cols)
    for col_img in cols:
        cells = np.vsplit(col_img, clue_rows)
        nums = [n for cell in cells for n in read_cell(cell)]
        column_clues.append(nums)

    return column_clues

def main():
    parser = argparse.ArgumentParser(
        description="Extract column clues from a Nonogram top‐strip image."
    )
    parser.add_argument("image", help="Top‐clue strip image file")
    parser.add_argument("--cols",      type=int, required=True,
                        help="Number of puzzle columns")
    parser.add_argument("--clue-rows", type=int, required=True,
                        help="Number of clue‐rows at top")
    parser.add_argument("--psm",       type=int, default=6,
                        help="Tesseract --psm mode (default: 6)")
    args = parser.parse_args()

    cols = extract_column_clues(
        args.image,
        args.cols,
        args.clue_rows,
        args.psm
    )
    print("columnClues =", cols)

if __name__ == "__main__":
    main()