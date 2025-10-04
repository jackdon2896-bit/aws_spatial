import sys, cv2
img = cv2.imread(sys.argv[1], 0)
mask = (img < 10).astype('uint8')
filled = cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)
cv2.imwrite(sys.argv[2], filled)