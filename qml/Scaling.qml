import QtQuick 2.3
import QtQuick.Window 2.2

QtObject {
  property double defaultWidthPx: 1920
  property double defaultWidthMM: 310
  property double defaultHeightPx: 1080
  property double defaultHeightMM: 174
  property double defaultPixelDensity: {
    0.5 * (defaultWidthPx/defaultWidthMM + defaultHeightPx/defaultHeightMM)
  }

  property double scalePixelDensity: Screen.pixelDensity / defaultPixelDensity
  property double scale: scalePixelDensity * controller.getFontScale()

  property int fontHuge:   scale * 20
  property int fontLarge:  scale * 18
  property int fontMedium: scale * 16
  property int fontSmall:  scale * 14
  property int fontTiny:   scale * 12
}
