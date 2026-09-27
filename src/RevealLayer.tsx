import type { CSSProperties } from 'react'

interface RevealLayerProps {
  image: string
  cursorX: number
  cursorY: number
}

function RevealLayer({
  image,
  cursorX,
  cursorY,
}: RevealLayerProps) {
  const revealStyle: CSSProperties = {
    backgroundImage: `url(${image})`,
    '--cursor-x': `${cursorX}px`,
    '--cursor-y': `${cursorY}px`,
  } as CSSProperties

  return (
    <div
      className="reveal-layer"
      style={revealStyle}
      aria-hidden="true"
    />
  )
}

export default RevealLayer
