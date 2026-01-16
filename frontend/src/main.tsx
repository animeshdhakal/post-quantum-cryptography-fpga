import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
<<<<<<< Current (Your changes)
import { applyThemeMode, getStoredThemeMode } from './lib/theme'

applyThemeMode(getStoredThemeMode());
=======
import { initTheme } from './lib/theme'

initTheme("dark")
>>>>>>> Incoming (Background Agent changes)

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
