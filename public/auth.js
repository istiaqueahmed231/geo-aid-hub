// auth.js – shared Firebase Auth logic (client‑only)

// Initialize Firebase app
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.23.0/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, onAuthStateChanged, signOut } from "https://www.gstatic.com/firebasejs/9.23.0/firebase-auth.js";
import { firebaseConfig } from "./firebase-config.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

// Helper to show toast messages (assumes a global showToast function exists)
function toast(msg, isError = false) {
  if (window && typeof window.showToast === "function") {
    window.showToast(msg, isError);
  } else {
    alert(msg);
  }
}

// Login function – called from login.html
export function login() {
  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;
  if (!email || !password) {
    toast("Please enter email & password", true);
    return;
  }
  signInWithEmailAndPassword(auth, email, password)
    .then((userCredential) => {
      toast("Login successful");
      // Redirect to main dashboard (index.html)
      window.location.href = "index.html";
    })
    .catch((error) => {
      toast(error.message, true);
    });
}

// Sign‑up function – called from signup.html
export function signup() {
  try {
    const email = document.getElementById("email").value.trim();
    const password = document.getElementById("password").value;
    const name = document.getElementById("name").value.trim();
    const status = document.getElementById("status").value.trim();
    const location = document.getElementById("location").value.trim();
    
    // Optional fields
    const ageElem = document.getElementById("age");
    const genderElem = document.getElementById("gender");
    const age = ageElem ? ageElem.value.trim() : null;
    const gender = genderElem ? genderElem.value.trim() : null;

    if (!email || !password || !name) {
      toast("Email, password and name are required", true);
      return;
    }

    createUserWithEmailAndPassword(auth, email, password)
      .then((userCredential) => {
        const uid = userCredential.user.uid;
        // Send extra profile data to backend
        fetch("/api/volunteers", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ uid, email, name, status, location, age, gender })
        })
          .then(async (res) => {
            const data = await res.json();
            if (!res.ok) {
              throw new Error(data.error || "Failed to save profile");
            }
            return data;
          })
          .then((data) => {
            toast("Account created and profile saved");
            // NOTE: monitorAuth() will automatically redirect the user to index.html 
            // since their Firebase state just became Authenticated. Setting href just in case.
            window.location.href = "index.html";
          })
          .catch((err) => {
            console.error(err);
            toast(err.message || "Failed to save profile on backend", true);
          });
      })
      .catch((error) => {
        toast(error.message, true);
      });
  } catch (err) {
    console.error("Synchronous error during signup:", err);
    toast(err.message || "An unexpected error occurred", true);
  }
}

// Logout function
export function logout() {
  signOut(auth).then(() => {
    window.location.href = "welcome.html";
  }).catch((error) => {
    toast(error.message, true);
  });
}

// Listen for auth state changes – redirect unauthenticated users to login
export function monitorAuth() {
  onAuthStateChanged(auth, (user) => {
    // Always expose current user globally so other scripts can read UID
    window.currentFirebaseUser = user || null;

    const isPublicPage = window.location.pathname.endsWith("welcome.html") || 
                         window.location.pathname.endsWith("login.html") || 
                         window.location.pathname.endsWith("signup.html") ||
                         window.location.pathname === "/" && !window.location.pathname.endsWith("index.html");
                         
    if (!user) {
      if (!isPublicPage) {
        window.location.href = "welcome.html";
      }
    } else {
      if (isPublicPage) {
        window.location.href = "index.html";
      }
      // Fire a custom event so non-module scripts know auth is ready
      window.dispatchEvent(new CustomEvent("authReady", { detail: { uid: user.uid } }));
    }
  });
}

// Expose functions to the global window object so HTML inline event handlers find them
window.login = login;
window.signup = signup;
window.logout = logout;

// Initialize monitoring when script loads
monitorAuth();
