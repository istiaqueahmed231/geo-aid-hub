// auth.js – shared Firebase Auth logic (client‑only)

// Initialize Firebase app
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js";
import { getAuth, signInWithEmailAndPassword, createUserWithEmailAndPassword, onAuthStateChanged } from "https://www.gstatic.com/firebasejs/9.23.0/firebase-auth-compat.js";
import { firebaseConfig } from "../firebase-config.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

// Helper to show toast messages (assumes a global showToast function exists)
function toast(msg, isError = false) {
  if (typeof showToast === "function") {
    showToast(msg, isError);
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
  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;
  const name = document.getElementById("name").value.trim();
  const status = document.getElementById("status").value.trim();
  const location = document.getElementById("location").value.trim();
  const age = document.getElementById("age").value.trim();
  const gender = document.getElementById("gender").value.trim();

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
        .then((res) => res.json())
        .then((data) => {
          toast("Account created and profile saved");
          window.location.href = "index.html";
        })
        .catch((err) => {
          console.error(err);
          toast("Failed to save profile", true);
        });
    })
    .catch((error) => {
      toast(error.message, true);
    });
}

// Listen for auth state changes – redirect unauthenticated users to login
export function monitorAuth() {
  onAuthStateChanged(auth, (user) => {
    if (!user) {
      // Not logged in – send to login page
      if (!window.location.pathname.endsWith("login.html")) {
        window.location.href = "login.html";
      }
    }
  });
}

// Initialize monitoring when script loads
monitorAuth();
