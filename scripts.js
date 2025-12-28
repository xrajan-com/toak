
    // Quote Cycling
    const quotes = [
      "You got to know when to hold 'em, know when to fold 'em",
      "Know when to walk away and know when to run",
      "You never count your money when you're sittin' at the table",
      "There'll be time enough for countin' when the dealings done",
    ];

    let currentQuote = 0;
    const quoteEl = document.getElementById("digital-quote");

    function showNextQuote() {
      quoteEl.style.opacity = 0;
      setTimeout(() => {
        quoteEl.textContent = `"${quotes[currentQuote]}"`;
        quoteEl.style.opacity = 1;
        currentQuote = (currentQuote + 1) % quotes.length;
      }, 1000);
    }

    showNextQuote();
    setInterval(showNextQuote, 6000);

    // Falling Suit Animation
    const suits = ['♥️', '♦️', '♣️', '♠️'];
    const colors = {
      '♥️': '#ff4d4d',
      '♦️': '#ff4d4d',
      '♣️': '#ffffff',
      '♠️': '#ffffff'
    };

    const container = document.querySelector('.falling-container');
    const numberOfSuits = 60;
    const fragment = document.createDocumentFragment();

    for (let i = 0; i < numberOfSuits; i++) {
      const suit = document.createElement('div');
      suit.className = 'falling-suit';
      const symbol = suits[Math.floor(Math.random() * suits.length)];
      suit.innerText = symbol;
      suit.style.left = Math.random() * 100 + 'vw';
      suit.style.fontSize = Math.random() * 20 + 20 + 'px';
      suit.style.animationDuration = (Math.random() * 5 + 5) + 's';
      suit.style.animationDelay = Math.random() * 5 + 's';
      suit.style.color = colors[symbol];
      fragment.appendChild(suit);
    }

    container.appendChild(fragment);

    // Login/Register Modal Functionality
    const openModalBtn = document.getElementById('openLoginModal');
    const modalOverlay = document.getElementById('loginRegisterModal');
    const closeModalBtn = document.getElementById('closeModal');
    const modalTitle = document.getElementById('modalTitle');
    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    const switchToRegisterLink = document.getElementById('switchToRegister');
    const switchToLoginLink = document.getElementById('switchToLogin');

    function openLoginRegisterModal() {
      modalOverlay.classList.add('active');
      document.body.style.overflow = 'hidden'; // Prevent scrolling when modal is open
    }

    function closeLoginRegisterModal() {
      modalOverlay.classList.remove('active');
      document.body.style.overflow = ''; // Restore scrolling
      // Reset to login form when closing
      modalTitle.textContent = 'Login';
      loginForm.style.display = 'flex';
      registerForm.style.display = 'none';
      loginForm.reset(); // Clear form fields
      registerForm.reset(); // Clear form fields
    }

    function showLoginForm() {
      modalTitle.textContent = 'Login';
      loginForm.style.display = 'flex';
      registerForm.style.display = 'none';
      loginForm.reset();
    }

    function showRegisterForm() {
      modalTitle.textContent = 'Register';
      loginForm.style.display = 'none';
      registerForm.style.display = 'flex';
      registerForm.reset();
    }

    openModalBtn.addEventListener('click', (e) => {
      e.preventDefault(); // Prevent default anchor behavior
      closeProfileModal(); // Close profile modal if open
      openLoginRegisterModal();
    });

    closeModalBtn.addEventListener('click', closeLoginRegisterModal);

    // Close login/register modal if user clicks outside the modal content
    modalOverlay.addEventListener('click', (e) => {
      if (e.target === modalOverlay) {
        closeLoginRegisterModal();
      }
    });

    switchToRegisterLink.addEventListener('click', (e) => {
      e.preventDefault();
      showRegisterForm();
    });

    switchToLoginLink.addEventListener('click', (e) => {
      e.preventDefault();
      showLoginForm();
    });

    // Basic form submission handling (for demonstration)
    loginForm.addEventListener('submit', (e) => {
      e.preventDefault();
      alert('Login functionality not implemented yet!');
      // In a real application, you'd send this data to a server
      // console.log('Login data:', {
      //   email: loginEmail.value,
      //   password: loginPassword.value
      // });
      closeLoginRegisterModal();
    });

    registerForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const password = document.getElementById('registerPassword').value;
      const confirmPassword = document.getElementById('confirmPassword').value;

      if (password !== confirmPassword) {
        alert('Passwords do not match!');
        return;
      }
      alert('Registration functionality not implemented yet!');
      // In a real application, you'd send this data to a server
      // console.log('Register data:', {
      //   username: registerUsername.value,
      //   email: registerEmail.value,
      //   password: registerPassword.value
      // });
      closeLoginRegisterModal();
    });

    // Profile Modal Functionality
    const profileModal = document.getElementById('profileModal');
    const profileIconLink = document.querySelector('.profile-icon-link');
    const closeProfileModalBtn = document.getElementById('closeProfileModal');
    const editProfileBtn = document.getElementById('editProfileBtn');
    const logoutBtn = document.getElementById('logoutBtn');

    // New DOM elements for profile details
    const profileAvatar = document.getElementById('profileAvatar');
    const profileUsername = document.getElementById('profileUsername');
    const profileEmail = document.getElementById('profileEmail');
    const profileKingdom = document.getElementById('profileKingdom');
    const profilePrizeMoney = document.getElementById('profilePrizeMoney');


    // Function to open the profile modal
    function openProfileModal() {
      profileModal.classList.add('active');
      document.body.style.overflow = 'hidden'; // Prevent scrolling
      // Here you would dynamically load user data if they are logged in
      // For demonstration, we'll use placeholder data
      const userData = {
        username: 'PokerKing',
        email: 'pokerking@example.com',
        avatar: 'https://via.placeholder.com/100/24b6ff/000000?text=PK', // Placeholder image, replace with actual user avatar URL
        kingdom: 'Maratha Confederacy', // Example chosen kingdom
        prizeMoney: 12500.75 // Example prize money
      };

      profileAvatar.src = userData.avatar;
      profileUsername.textContent = userData.username;
      profileEmail.textContent = userData.email;
      profileKingdom.textContent = userData.kingdom;
      profilePrizeMoney.textContent = `$${userData.prizeMoney.toFixed(2)}`; // Format as currency
    }

    // Function to close the profile modal
    function closeProfileModal() {
      profileModal.classList.remove('active');
      document.body.style.overflow = ''; // Restore scrolling
    }

    // Event Listeners for Profile Modal
    profileIconLink.addEventListener('click', (e) => {
      e.preventDefault(); // Prevent default anchor behavior
      closeLoginRegisterModal(); // Close login/register modal if open
      openProfileModal();
    });

    closeProfileModalBtn.addEventListener('click', closeProfileModal);

    profileModal.addEventListener('click', (e) => {
      if (e.target === profileModal) {
        closeProfileModal();
      }
    });

    editProfileBtn.addEventListener('click', () => {
      alert('Edit Profile functionality coming soon!');
      // In a real application, this would open an edit profile form or page
      closeProfileModal();
    });

    logoutBtn.addEventListener('click', () => {
      alert('Logged out!');
      // In a real application, this would handle user logout (clear session, redirect, etc.)
      closeProfileModal();
    });

    // Close any modal with Escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        if (modalOverlay.classList.contains('active')) {
          closeLoginRegisterModal();
        } else if (profileModal.classList.contains('active')) {
          closeProfileModal();
        }
      }
    });

    // Existing JavaScript

document.addEventListener('DOMContentLoaded', () => {
    // ... existing modal and form handling ...

    const loginRegisterModal = document.getElementById('loginRegisterModal');
    const openLoginModalBtn = document.getElementById('openLoginModal');
    const closeModalBtn = document.getElementById('closeModal');
    const loginForm = document.getElementById('loginForm');
    const registerForm = document.getElementById('registerForm');
    const switchToRegisterBtn = document.getElementById('switchToRegister');
    const switchToLoginBtn = document.getElementById('switchToLogin');
    const modalTitle = document.getElementById('modalTitle');

    // Profile Modal elements
    const profileModal = document.getElementById('profileModal');
    const closeProfileModalBtn = document.getElementById('closeProfileModal');
    const profileIconLink = document.querySelector('.profile-icon-link');
    const profileUsernameSpan = document.getElementById('profileUsername');
    const profileEmailSpan = document.getElementById('profileEmail');
    const profileKingdomSpan = document.getElementById('profileKingdom');
    const profilePrizeMoneySpan = document.getElementById('profilePrizeMoney');
    const profileAvatarImg = document.getElementById('profileAvatar');
    const editProfileBtn = document.getElementById('editProfileBtn');
    const logoutBtn = document.getElementById('logoutBtn');

    // New ID Card elements
    const viewIdCardBtn = document.getElementById('viewIdCardBtn');
    const idCardDisplay = document.querySelector('.id-card-display');
    const closeIdCardBtn = document.getElementById('closeIdCardBtn');
    const idCardPhoto = document.getElementById('idCardPhoto');
    const idCardUsername = document.getElementById('idCardUsername');
    const idCardKingdom = document.getElementById('idCardKingdom');
    const idCardKingdomFlag = document.getElementById('idCardKingdomFlag');
    const idCardAbout = document.getElementById('idCardAbout');

    // New register form fields
    const userPhotoInput = document.getElementById('userPhoto');
    const aboutUserInput = document.getElementById('aboutUser');

    // Simulating user data (replace with actual backend/localStorage in a real app)
    let currentUser = null; // Will store the logged-in user's data

    // --- Modal Logic ---
    openLoginModalBtn.addEventListener('click', (e) => {
        e.preventDefault();
        loginRegisterModal.style.display = 'block';
        modalTitle.textContent = 'Login';
        loginForm.style.display = 'block';
        registerForm.style.display = 'none';
    });

    closeModalBtn.addEventListener('click', () => {
        loginRegisterModal.style.display = 'none';
    });

    switchToRegisterBtn.addEventListener('click', (e) => {
        e.preventDefault();
        modalTitle.textContent = 'Register';
        loginForm.style.display = 'none';
        registerForm.style.display = 'block';
    });

    switchToLoginBtn.addEventListener('click', (e) => {
        e.preventDefault();
        modalTitle.textContent = 'Login';
        loginForm.style.display = 'block';
        registerForm.style.display = 'none';
    });

    // --- Login Form Submission ---
    loginForm.addEventListener('submit', (e) => {
        e.preventDefault();
        const email = document.getElementById('loginEmail').value;
        const password = document.getElementById('loginPassword').value;

        // In a real application, you'd send this to a server for authentication.
        // For demonstration, let's simulate a successful login.
        if (email === 'user@example.com' && password === 'password123') {
            currentUser = {
                username: 'LoggedInPlayer',
                email: 'user@example.com',
                kingdom: 'Sikh Empire', // Example kingdom
                prizeMoney: 1500.75,
                photo: 'https://via.placeholder.com/150/0000FF/FFFFFF?text=LP', // Example photo
                about: 'A true poker enthusiast!',
                kingdomFlag: '640px/Sikh Empire.png' // Corresponding flag path
            };
            alert('Login successful!');
            loginRegisterModal.style.display = 'none';
            updateProfileUI(); // Update profile immediately after login
        } else {
            alert('Invalid email or password.');
        }
        loginForm.reset();
    });

    // --- Register Form Submission ---
    registerForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('registerUsername').value;
        const email = document.getElementById('registerEmail').value;
        const password = document.getElementById('registerPassword').value;
        const confirmPassword = document.getElementById('confirmPassword').value;
        const photoFile = userPhotoInput.files[0]; // Get the selected file
        const about = aboutUserInput.value;

        if (password !== confirmPassword) {
            alert('Passwords do not match.');
            return;
        }

        // Basic uniqueness check (in a real app, this would be server-side)
        if (username === 'LoggedInPlayer') { // Example of a taken username
            alert('Username already taken. Please choose another.');
            return;
        }

        let compressedPhotoUrl = 'placeholder.jpg'; // Default if no photo or error

        if (photoFile) {
            try {
                compressedPhotoUrl = await compressImage(photoFile, 150, 150, 0.7); // Compress to 150x150, 70% quality
            } catch (error) {
                console.error('Error compressing image:', error);
                alert('Failed to process image. Please try again or choose a different image.');
                return;
            }
        }

        // In a real application, you'd send this data to a server for registration.
        currentUser = {
            username: username,
            email: email,
            kingdom: getRandomKingdom(), // Assign a random kingdom for new users
            prizeMoney: 0.00,
            photo: compressedPhotoUrl,
            about: about,
            kingdomFlag: `640px/${getRandomKingdom().replace(/ /g, '%20')}.png` // Construct flag path
        };

        alert('Registration successful! You are now logged in.');
        loginRegisterModal.style.display = 'none';
        updateProfileUI(); // Update profile immediately after registration
        registerForm.reset();
        userPhotoInput.value = ''; // Clear file input
    });

    // --- Profile Modal Logic ---
    profileIconLink.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentUser) {
            updateProfileUI();
            profileModal.style.display = 'block';
            idCardDisplay.style.display = 'none'; // Ensure ID card is hidden by default
        } else {
            alert('Please login or register to view your profile.');
            openLoginModalBtn.click(); // Open login modal if not logged in
        }
    });

    closeProfileModalBtn.addEventListener('click', () => {
        profileModal.style.display = 'none';
    });

    editProfileBtn.addEventListener('click', () => {
        alert('Edit profile functionality (not implemented in this demo).');
    });

    logoutBtn.addEventListener('click', () => {
        currentUser = null;
        alert('You have been logged out.');
        profileModal.style.display = 'none';
        // Optionally redirect or update UI to reflect logged-out state
    });

    // --- ID Card Logic ---
    viewIdCardBtn.addEventListener('click', () => {
        if (currentUser) {
            idCardDisplay.style.display = 'block';
            updateIdCardUI();
        }
    });

    closeIdCardBtn.addEventListener('click', () => {
        idCardDisplay.style.display = 'none';
    });

    // --- Helper Functions ---

    function updateProfileUI() {
        if (currentUser) {
            profileUsernameSpan.textContent = currentUser.username;
            profileEmailSpan.textContent = currentUser.email;
            profileKingdomSpan.textContent = currentUser.kingdom;
            profilePrizeMoneySpan.textContent = `$${currentUser.prizeMoney.toFixed(2)}`;
            profileAvatarImg.src = currentUser.photo || 'placeholder.jpg';
        }
    }

    function updateIdCardUI() {
        if (currentUser) {
            idCardPhoto.src = currentUser.photo || 'placeholder.jpg';
            idCardUsername.textContent = currentUser.username;
            idCardKingdom.textContent = currentUser.kingdom;
            idCardKingdomFlag.src = currentUser.kingdomFlag;
            idCardKingdomFlag.alt = `Flag of ${currentUser.kingdom}`;
            idCardAbout.textContent = currentUser.about;
        }
    }

    const kingdoms = [
        "Baroda", "New Delhi", "Hyderabad", "Indore", "Jaipur",
        "Maratha Empire", "Mysore", "Sikh Empire", "Sikkim", "Travancore"
    ];

    function getRandomKingdom() {
        const randomIndex = Math.floor(Math.random() * kingdoms.length);
        return kingdoms[randomIndex];
    }

    // Image Compression Function
    // This function takes a File object, target width/height, and quality
    // and returns a Promise that resolves with a base64 encoded data URL of the compressed image.
    function compressImage(file, maxWidth, maxHeight, quality) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = (event) => {
                const img = new Image();
                img.src = event.target.result;
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    let width = img.width;
                    let height = img.height;

                    // Calculate new dimensions while maintaining aspect ratio
                    if (width > height) {
                        if (width > maxWidth) {
                            height *= maxWidth / width;
                            width = maxWidth;
                        }
                    } else {
                        if (height > maxHeight) {
                            width *= maxHeight / height;
                            height = maxHeight;
                        }
                    }

                    canvas.width = width;
                    canvas.height = height;

                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, width, height);

                    // Convert canvas to base64 image data (JPEG for better compression)
                    const dataUrl = canvas.toDataURL('image/jpeg', quality);
                    resolve(dataUrl);
                };
                img.onerror = (error) => reject(error);
            };
            reader.onerror = (error) => reject(error);
        });
    }
    // --- Dynamic Quote Billboard (existing) ---
    const digitalQuoteElement = document.getElementById('digital-quote');
    const quotes = [
        "The only certainty in poker is that there is no certainty.",
        "Poker is a game of skill, not luck... eventually.",
        "It's not enough to win, others must lose.",
        "Show me a good loser, and I'll show you a loser.",
        "Trust everyone, but always cut the cards.",
        "The beautiful thing about poker is that it’s not about the cards you are dealt, but how you play the hand."
    ];
    let currentQuoteIndex = 0;

    function updateQuote() {
        digitalQuoteElement.textContent = quotes[currentQuoteIndex];
        currentQuoteIndex = (currentQuoteIndex + 1) % quotes.length;
    }

    // Update quote every 5 seconds
    setInterval(updateQuote, 5000);
    updateQuote(); // Display initial quote
});
  