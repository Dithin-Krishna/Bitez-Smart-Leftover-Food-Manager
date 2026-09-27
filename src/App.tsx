import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
} from 'react'

import {
  Menu,
  X,
  ArrowRight,
} from 'lucide-react'

import RevealLayer from './RevealLayer'
import { BG_IMAGE_1, BG_IMAGE_2 } from './constants'

import HomeDashboard from './HomeDashboard'

import './index.css'

const NAV_LINKS = [
  'Dashboard',
  'Registered Users',
  'Food Analytics',
  'Sustainability',
  'Suggestions',
  'Help Centre',
]

function BitezLogo() {
  return (
    <div className="bitez-logo-icon">
      B
    </div>
  )
}

function App() {
  const [mobileOpen, setMobileOpen] = useState(false)

  const [isLogin, setIsLogin] = useState(false)

  // FIX: Initialize state from localStorage to persist across refreshes
  const [showDashboard, setShowDashboard] = useState<boolean>(() => {
    return localStorage.getItem('bitez_logged_in') === 'true'
  })

  const mouse = useRef({
    x: -999,
    y: -999,
  })

  const smoothMouse = useRef({
    x: -999,
    y: -999,
  })

  const animationFrame =
    useRef<number | null>(null)

  const [cursorPosition, setCursorPosition] =
    useState({
      x: -999,
      y: -999,
    })

  /*
  =====================================
  MOUSE REVEAL EFFECT
  =====================================
  */

  useEffect(() => {
    const handleMouseMove =
      (event: MouseEvent) => {
        mouse.current = {
          x: event.clientX,
          y: event.clientY,
        }
      }

    window.addEventListener(
      'mousemove',
      handleMouseMove,
    )

    const animateMouse = () => {
      smoothMouse.current.x +=
        (mouse.current.x -
          smoothMouse.current.x) *
        0.1

      smoothMouse.current.y +=
        (mouse.current.y -
          smoothMouse.current.y) *
        0.1

      setCursorPosition({
        x: smoothMouse.current.x,
        y: smoothMouse.current.y,
      })

      animationFrame.current =
        requestAnimationFrame(
          animateMouse,
        )
    }

    animationFrame.current =
      requestAnimationFrame(
        animateMouse,
      )

    return () => {
      window.removeEventListener(
        'mousemove',
        handleMouseMove,
      )

      if (
        animationFrame.current !== null
      ) {
        cancelAnimationFrame(
          animationFrame.current,
        )
      }
    }
  }, [])

  /*
  =====================================
  LOGIN / SIGNUP
  =====================================
  */

  const handleSubmit = (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault()

    // MongoDB authentication
    // can be connected here later

    // FIX: Save login status to localStorage
    localStorage.setItem('bitez_logged_in', 'true')
    setShowDashboard(true)
  }

  /*
  =====================================
  LOGOUT
  =====================================
  */

  const handleLogout = () => {
    // FIX: Remove login status from localStorage on logout
    localStorage.removeItem('bitez_logged_in')
    setShowDashboard(false)

    setIsLogin(true)

    setMobileOpen(false)
  }

  /*
  =====================================
  LOAD DASHBOARD
  =====================================
  */

  if (showDashboard) {
    return (
      <HomeDashboard
        onLogout={handleLogout}
      />
    )
  }

  /*
  =====================================
  LOGIN / SIGNUP PAGE
  =====================================
  */

  return (
    <div className="lithos-app">

      {/* ============================= */}
      {/* NAVIGATION */}
      {/* ============================= */}

      <nav className="lithos-nav">

        {/* LOGO */}

        <button
          type="button"
          className="logo-button"
          onClick={() => {
            window.scrollTo({
              top: 0,
              behavior: 'smooth',
            })
          }}
        >
          <BitezLogo />

          <span>
            BITEZ
          </span>

        </button>

        {/* DESKTOP NAVIGATION */}

        <div className="desktop-nav">

          {NAV_LINKS.map((link) => (
            <button
              key={link}
              type="button"
            >
              {link}
            </button>
          ))}

        </div>

        {/* MOBILE MENU BUTTON */}

        <button
          type="button"
          className="mobile-menu"
          onClick={() => {
            setMobileOpen(!mobileOpen)
          }}
        >
          {mobileOpen ? (
            <X size={24} />
          ) : (
            <Menu size={24} />
          )}
        </button>

        {/* MOBILE NAVIGATION */}

        {mobileOpen && (
          <div className="mobile-nav">

            {NAV_LINKS.map(
              (link) => (
                <button
                  key={link}
                  type="button"
                  onClick={() => {
                    setMobileOpen(false)
                  }}
                >
                  {link}
                </button>
              ),
            )}

            <button
              type="button"
              className="mobile-signup"
              onClick={() => {
                setIsLogin(false)

                setMobileOpen(false)
              }}
            >
              Sign Up
            </button>

          </div>
        )}

      </nav>

      {/* ============================= */}
      {/* HERO */}
      {/* ============================= */}

      <main className="hero-page">

        {/* BACKGROUND IMAGE */}

        <div
          className="hero-image"
          style={{
            backgroundImage:
              `url(${BG_IMAGE_1})`,
          }}
        />

        {/* CURSOR REVEAL */}

        <RevealLayer
          image={BG_IMAGE_2}
          cursorX={cursorPosition.x}
          cursorY={cursorPosition.y}
        />

        {/* DARK OVERLAY */}

        <div className="hero-dark-overlay" />

        {/* ============================= */}
        {/* HERO CONTENT */}
        {/* ============================= */}

        <section className="hero-content">

          <div className="hero-tag">
            SMART LEFTOVER FOOD MANAGER
          </div>

          <h1>

            <span className="italic-title">
              Leftovers aren't
            </span>

            <span>
              the end of a meal.
            </span>

          </h1>

          <p className="hero-description">
            Manage smarter. Waste less.
            Make an impact.
          </p>

          <p className="hero-long-description">
            BITEZ helps you manage
            leftover food, track expiry
            dates, discover recipes,
            reduce food waste and make
            every bite count.
          </p>

          {/* BUTTON */}

          <div className="hero-actions">

            <button
              type="button"
              className="primary-button"
              onClick={() => {
                setIsLogin(false)

                const authSection =
                  document.querySelector(
                    '.auth-panel',
                  )

                authSection?.scrollIntoView({
                  behavior: 'smooth',
                  block: 'center',
                })

                authSection?.classList.add(
                  'auth-highlight',
                )

                setTimeout(() => {
                  authSection?.classList.remove(
                    'auth-highlight',
                  )
                }, 1500)
              }}
            >
              Start making every bite count.

              <ArrowRight size={18} />

            </button>

          </div>

          {/* FEATURES */}

          <div className="hero-features">

            <div>

              <strong>
                AI Powered
              </strong>

              <span>
                Smart food recognition
              </span>

            </div>

            <div>

              <strong>
                Less Waste
              </strong>

              <span>
                Track expiry dates
              </span>

            </div>

            <div>

              <strong>
                More Impact
              </strong>

              <span>
                Sustainable living
              </span>

            </div>

          </div>

        </section>

        {/* ============================= */}
        {/* AUTH PANEL */}
        {/* ============================= */}

        <section className="auth-wrapper">

          <div className="auth-panel">

            {/* BRAND */}

            <div className="auth-brand">

              <div className="auth-logo">
                B
              </div>

              <span>
                BITEZ
              </span>

            </div>

            {/* TABS */}

            <div className="auth-tabs">

              <button
                type="button"
                className={
                  !isLogin
                    ? 'active-tab'
                    : ''
                }
                onClick={() => {
                  setIsLogin(false)
                }}
              >
                Sign Up
              </button>

              <button
                type="button"
                className={
                  isLogin
                    ? 'active-tab'
                    : ''
                }
                onClick={() => {
                  setIsLogin(true)
                }}
              >
                Login
              </button>

            </div>

            {/* HEADING */}

            <div className="auth-heading">

              <h2>
                {isLogin
                  ? 'Welcome back'
                  : 'Join the movement'}
              </h2>

              <p>
                {isLogin
                  ? 'Continue to the BITEZ admin dashboard.'
                  : 'Create your admin account to manage BITEZ.'}
              </p>

            </div>

            {/* FORM */}

            <form
              className="signup-form"
              onSubmit={handleSubmit}
            >

              {/* ADMIN NAME */}

              {!isLogin && (

                <div className="input-group">

                  <label htmlFor="name">
                    ADMIN NAME
                  </label>

                  <input
                    id="name"
                    type="text"
                    placeholder="Enter admin name"
                    required
                  />

                </div>

              )}

              {/* EMAIL */}

              <div className="input-group">

                <label htmlFor="email">
                  ADMIN EMAIL
                </label>

                <input
                  id="email"
                  type="email"
                  placeholder="admin@example.com"
                  required
                />

              </div>

              {/* PASSWORD */}

              <div className="input-group">

                <label htmlFor="password">
                  PASSWORD
                </label>

                <input
                  id="password"
                  type="password"
                  placeholder="Enter your password"
                  required
                />

              </div>

              {/* CONFIRM PASSWORD */}

              {!isLogin && (

                <div className="input-group">

                  <label htmlFor="confirmPassword">
                    CONFIRM PASSWORD
                  </label>

                  <input
                    id="confirmPassword"
                    type="password"
                    placeholder="Confirm your password"
                    required
                  />

                </div>

              )}

              {/* FORGOT PASSWORD */}

              {isLogin && (

                <button
                  type="button"
                  className="forgot-password"
                >
                  Forgot password?
                </button>

              )}

              {/* SUBMIT */}

              <button
                type="submit"
                className="create-account-button"
              >

                {isLogin
                  ? 'Login to Dashboard'
                  : 'Create Admin Account'}

                <ArrowRight size={18} />

              </button>

            </form>

            {/* FOOTER */}

            <div className="auth-footer">

              <span>

                {isLogin
                  ? "Don't have an account?"
                  : 'Already have an account?'}

              </span>

              <button
                type="button"
                onClick={() => {
                  setIsLogin(!isLogin)
                }}
              >

                {isLogin
                  ? 'Sign Up'
                  : 'Login'}

              </button>

            </div>

          </div>

        </section>

        {/* ============================= */}
        {/* BOTTOM TEXT */}
        {/* ============================= */}

        <div className="scroll-indicator">

          <span>
            DISCOVER SMARTER FOOD MANAGEMENT
          </span>

          <div />

        </div>

      </main>

    </div>
  )
}

export default App