import QtQuick 2.3
import QtQuick.Window 2.2

QtObject {

  // CONFIG

  /* default screen size to scale (14" 1080p) */
  property double defaultWidthPx: 1920
  property double defaultWidthMM: 310
  property double defaultHeightPx: 1080
  property double defaultHeightMM: 174

  /* limit scaling down for larger screens (usually also further away) */
  property double minScalePhysicalSize: 0.8

  // RUNTIME VALUES

  property double screenWidthPx: Screen.width
  property double screenWidthMM: Screen.width / Screen.pixelDensity
  property double screenHeightPx: Screen.height
  property double screenHeightMM: Screen.height / Screen.pixelDensity

  // CALCULATIONS

  /* average of height and width pixel count ratio */
  property double ratioPx: {
    (screenWidthPx/defaultWidthPx + screenHeightPx/defaultHeightPx) / 2.0
  }
  /* average of height and width physical size ratio */
  property double ratioPhysicalSize: {
    (screenWidthMM/defaultWidthMM + screenHeightMM/defaultHeightMM) / 2.0
  }

  /* scale up for smaller screens, scale down to a certain point for larger */
  property double scalePhysicalSize: Math.max(
    minScalePhysicalSize,
    1/ratioPhysicalSize
  )

  /* scale up for higher resolution, scale down for lower resolution */
  property double scalePxSize: ratioPx

  /* scale based on physical size and resolution */
  property double scalePixelDensity: scalePhysicalSize * scalePxSize

  /* scale based on resolution, screen size and optional command-line arg */
  property double scale: scalePixelDensity * controller.getFontScale()

  property int fontHuge:   scale * 20
  property int fontLarge:  scale * 18
  property int fontMedium: scale * 16
  property int fontSmall:  scale * 14
  property int fontTiny:   scale * 12
}
