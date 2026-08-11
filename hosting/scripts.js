// scripts/main.js

document.addEventListener("DOMContentLoaded", () => {
  const auth =
    window.firebase && typeof firebase.auth === "function" ? firebase.auth() : null;
  const db =
    window.firebase && typeof firebase.firestore === "function" ? firebase.firestore() : null;

  const _profileKey = (uid) => `tok.profile.${uid}`;
  const readExtraProfile = (uid) => {
    try {
      const raw = localStorage.getItem(_profileKey(uid));
      return raw ? JSON.parse(raw) : {};
    } catch (_) {
      return {};
    }
  };
  const writeExtraProfile = (uid, patch) => {
    const current = readExtraProfile(uid);
    const next = { ...current, ...patch };
    localStorage.setItem(_profileKey(uid), JSON.stringify(next));
    return next;
  };

  const firebaseErrorMessage = (e) => {
    const code = (e && e.code) ? String(e.code) : "";
    switch (code) {
      case "auth/email-already-in-use":
        return "Email already in use.";
      case "auth/invalid-email":
        return "Invalid email address.";
      case "auth/weak-password":
        return "Password is too weak (use 8+ characters).";
      case "auth/user-not-found":
      case "auth/wrong-password":
        return "Invalid email or password.";
      case "auth/too-many-requests":
        return "Too many attempts. Try again later.";
      default:
        return (e && e.message) ? String(e.message) : "Something went wrong.";
    }
  };

  const DOM = {
    editProfileBtn: document.getElementById("editProfileBtn"),
    editProfileForm: document.getElementById("editProfileForm"),
    loginModal: document.getElementById("loginRegisterModal"),
    profileModal: document.getElementById("profileModal"),
    leaderboardModal: document.getElementById("leaderboardModal"),
    aboutPopup: document.getElementById("aboutPopup"),
    supportPopup: document.getElementById("supportPopup"),
    venueModal: document.getElementById("venueDetailModal"),
    venueModalGroup: document.getElementById("venueModalGroup"),
    venueModalTitle: document.getElementById("venueModalTitle"),
    venueModalHistory: document.getElementById("venueModalHistory"),
    venueFortList: document.getElementById("venueFortList")
  };

  const flagByKingdom = {
    "Baroda": "baroda.png",
    "Hyderabad": "hyderabad.png",
    "Indore": "indore.png",
    "Jaipur": "jaipur.png",
    "Maratha Empire": "maratha-empire.png",
    "Mysore": "mysore.png",
    "New Delhi": "new-delhi.png",
    "Sikh Empire": "sikh-empire.png",
    "Sikkim": "sikkim.png",
    "Travancore": "travancore.png",
    "Africa": "africa.png",
    "Amazon": "amazon.png",
    "America": "america.png",
    "Arabia": "arabia.png",
    "Australia": "australia.png",
    "China": "china.png",
    "Europe": "europe.png",
    "India": "india.png",
    "Russia": "russia.png",
    "Southeast": "southeast.png",
    "Britain": "euro/britain.png",
    "France": "euro/france.png",
    "Italy": "euro/italy.png",
    "Spain": "euro/spain.png",
    "Portugal": "euro/portugal.png",
    "North Sea": "euro/north_sea.png",
    "Scandinavia": "euro/scandinavia.png",
    "Baltic Marches": "euro/baltic_marches.png",
    "Russia & Siberia": "euro/russia_siberia.png",
    "Mediterranean": "euro/mediterranean.png",
    "Alaska": "oceania/alaska.png",
    "Caribbean": "oceania/caribbean.png",
    "Dragonland": "oceania/dragonland.png",
    "Straits": "oceania/straits.png",
    "Indian Ocean": "oceania/indian_ocean.png",
    "Pacific": "oceania/pacific.png",
    "British Isles": "oceania/british_isles.png",
    "French Isles": "oceania/french_isles.png",
    "Dutch Isles": "oceania/dutch_isles.png",
    "American Isles": "oceania/american_isles.png",
    "Dominion of Canada": "us/canada.png",
    "Massachusetts": "us/massachusetts.png",
    "New York": "us/new_york.png",
    "Virginia": "us/virginia.png",
    "Illinois": "us/illinois.png",
    "Florida": "us/florida.png",
    "Texas": "us/texas.png",
    "Kansas": "us/kansas.png",
    "Colorado": "us/colorado.png",
    "California": "us/california.png"
  };

  const toggleModal = (el, show = true) => el.classList[show ? 'add' : 'remove']("active");
  const closeAllModals = () => document.querySelectorAll(".modal-overlay.active").forEach(el => toggleModal(el, false));

  function switchView(showLogin) {
    document.getElementById("loginForm").style.display = showLogin ? "block" : "none";
    document.getElementById("registerForm").style.display = showLogin ? "none" : "block";
    document.getElementById("modalTitle").innerText = showLogin ? "Login" : "Register";
  }

  const openLoginRegisterModal = () => {
    closeAllModals();
    switchView(true);
    toggleModal(DOM.loginModal, true);
  };

  const openLoginModalBtn = document.getElementById("openLoginModal");
  if (openLoginModalBtn) {
    openLoginModalBtn.addEventListener("click", (e) => {
      e.preventDefault();
      openLoginRegisterModal();
    });
  }

  const profileIconLink = document.querySelector(".profile-icon-link");
  const dashboardIconLink = document.querySelector(".dashboard-icon-link");
  const setProfileModalMode = (mode) => {
    if (!DOM.profileModal) return;
    const isDashboard = mode === "dashboard";
    DOM.profileModal.classList.toggle("profile-modal-dashboard", isDashboard);
    DOM.profileModal.classList.toggle("profile-modal-profile", !isDashboard);
    const title = document.getElementById("profileModalTitle");
    if (title) title.innerText = isDashboard ? "Dashboard" : "My Profile";
    if (DOM.editProfileForm) {
      DOM.editProfileForm.style.display = "none";
      if (DOM.editProfileBtn) DOM.editProfileBtn.innerText = "Edit Profile";
    }
  };
  const openProfileSurface = (mode) => {
    closeAllModals();
    const isSignedIn = Boolean(auth && auth.currentUser);
    if (mode === "profile" && !isSignedIn) {
      toggleModal(DOM.loginModal, true);
      switchView(true);
      return;
    }
    setProfileModalMode(mode);
    toggleModal(DOM.profileModal, true);
  };
  if (profileIconLink) {
    profileIconLink.addEventListener("click", (e) => {
      e.preventDefault();
      openProfileSurface("profile");
    });
  }
  if (dashboardIconLink) {
    dashboardIconLink.addEventListener("click", (e) => {
      e.preventDefault();
      openProfileSurface("dashboard");
    });
  }

  ["closeModal", "closeProfileModal", "closeLeaderboardModal", "closeVenueModal"].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener("click", closeAllModals);
  });

  document.querySelectorAll(".modal-overlay").forEach(overlay => {
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) closeAllModals();
    });
  });

  document.getElementById("switchToRegister").addEventListener("click", e => { e.preventDefault(); switchView(false); });
  document.getElementById("switchToLogin").addEventListener("click", e => { e.preventDefault(); switchView(true); });

  const popupPairs = [
    { trigger: "aboutLink", target: "aboutPopup" },
    { trigger: "supportLink", target: "supportPopup" },
    { trigger: "aboutLinkVenue", target: "aboutPopupVenue" },
    { trigger: "supportLinkVenue", target: "supportPopupVenue" },
    { trigger: "disclaimerLink", target: "disclaimerPopup" },
    { trigger: "disclaimerLinkVenue", target: "disclaimerPopupVenue" }
  ];

  const popupTimers = new Map();
  const hidePopup = (id) => {
    const el = document.getElementById(id);
    if (el) toggleModal(el, false);
  };
  const scheduleHide = (id) => {
    clearTimeout(popupTimers.get(id));
    const timeoutId = setTimeout(() => hidePopup(id), 2000);
    popupTimers.set(id, timeoutId);
  };
  const cancelHide = (id) => clearTimeout(popupTimers.get(id));

  popupPairs.forEach(({ trigger, target }) => {
    const triggerEl = document.getElementById(trigger);
    const targetEl = document.getElementById(target);
    if (!triggerEl || !targetEl) return;

    triggerEl.addEventListener("click", e => {
      e.preventDefault();
      // hide other popups first
      popupPairs.forEach(p => hidePopup(p.target));
      toggleModal(targetEl, true);
    });

    triggerEl.addEventListener("mouseleave", () => scheduleHide(target));
    triggerEl.addEventListener("mouseenter", () => cancelHide(target));
    targetEl.addEventListener("mouseenter", () => cancelHide(target));
    targetEl.addEventListener("mouseleave", () => scheduleHide(target));
  });

  document.querySelectorAll(".close-popup").forEach(btn => {
    btn.addEventListener("click", () => {
      [DOM.aboutPopup, DOM.supportPopup, document.getElementById("aboutPopupVenue"), document.getElementById("supportPopupVenue"), document.getElementById("disclaimerPopup"), document.getElementById("disclaimerPopupVenue")].forEach(p => p && toggleModal(p, false));
    });
  });

  const venueInfo = {
    "Baroda": {
      group: "Indian Circuit",
      history: "Baroda grew under the Gaekwads into one of western India's most reform-minded princely states, known for public works, education, and a confident court culture.",
      forts: [
        {
          name: "Dabhoi Fort",
          about: "Dabhoi's old fortifications preserve carved gates and Solanki-era stonework near Baroda. The town guarded trade routes and still reads like a compact fortified city."
        },
        {
          name: "Champaner-Pavagadh",
          about: "The Champaner-Pavagadh complex layers hill forts, mosques, stepwells, and royal remains across a volcanic ridge. It became a UNESCO site for its rare, largely unchanged pre-Mughal urban fabric."
        },
        {
          name: "Baroda Walled City Gates",
          about: "Mandvi and the old city gates mark Baroda's fortified urban core. They recall a capital built around trade, administration, and ceremonial movement through the city."
        }
      ]
    },
    "Hyderabad": {
      group: "Indian Circuit",
      history: "Hyderabad was the seat of the Qutb Shahi rulers and later the Asaf Jahi nizams, joining Persianate court style with Deccan military power and a wealthy trading culture.",
      forts: [
        {
          name: "Golconda Fort",
          about: "Golconda controlled the diamond-rich Deccan and became famous for its acoustic defenses, gateways, and layered walls. Its ruins still show how palace life and military design were fused."
        },
        {
          name: "Warangal Fort",
          about: "Warangal was a Kakatiya stronghold before later Deccan powers fought over it. Its carved gateways and stone remains point to a powerful medieval Telugu capital."
        },
        {
          name: "Medak Fort",
          about: "Medak Fort sits on a hill that watched the northern approaches to Hyderabad. Kakatiya, Bahmani, and Qutb Shahi phases are visible in its walls, granaries, and bastions."
        }
      ]
    },
    "Indore": {
      group: "Indian Circuit",
      history: "Indore rose with the Holkars, a Maratha house that turned a trading town into a central Indian power base while patronizing temples, markets, and river cities.",
      forts: [
        {
          name: "Ahilya Fort, Maheshwar",
          about: "Ahilya Fort overlooks the Narmada and is closely tied to Ahilyabai Holkar's enlightened rule. The fort-palace complex became a center of administration, devotion, and textile patronage."
        },
        {
          name: "Mandu Fort",
          about: "Mandu's plateau walls enclose palaces, reservoirs, and Afghan-era monuments. Its dramatic setting made it one of central India's most memorable fortified capitals."
        },
        {
          name: "Asirgarh Fort",
          about: "Asirgarh was called the key to the Deccan because armies moving south had to reckon with it. Mughals, Marathas, and later British forces all understood its strategic value."
        }
      ]
    },
    "Jaipur": {
      group: "Indian Circuit",
      history: "Jaipur was planned by Sawai Jai Singh II as a scientific, commercial, and royal capital, with Amber's older hill power feeding into the Pink City's urban design.",
      forts: [
        {
          name: "Amber Fort",
          about: "Amber Fort blends Rajput defense with mirrored halls, courtyards, and water systems. It was the Kachwaha seat before Jaipur became the planned capital."
        },
        {
          name: "Jaigarh Fort",
          about: "Jaigarh watched over Amber and housed artillery, armories, and treasury routes. Its long walls and cannon works made it a military backbone for the Jaipur rulers."
        },
        {
          name: "Nahargarh Fort",
          about: "Nahargarh crowns the Aravalli ridge above Jaipur. Built as a defensive retreat, it later became a scenic royal residence overlooking the city grid."
        }
      ]
    },
    "Maratha Empire": {
      group: "Indian Circuit",
      history: "The Maratha Empire grew from hill forts, mobile cavalry, and local revenue networks into a major early modern Indian power that challenged Mughal authority.",
      forts: [
        {
          name: "Raigad Fort",
          about: "Raigad was Chhatrapati Shivaji Maharaj's coronation capital. Its cliff defenses, gateways, and royal precinct made it a symbol of Maratha statehood."
        },
        {
          name: "Sinhagad Fort",
          about: "Sinhagad guarded the Pune region and is remembered for fierce Maratha campaigns. The fort's steep approaches explain why it was so hard to storm."
        },
        {
          name: "Sindhudurg Fort",
          about: "Sindhudurg was built in the Arabian Sea to strengthen Maratha naval power. Its sea walls and hidden entrances show a coastal strategy beyond hill warfare."
        }
      ]
    },
    "Mysore": {
      group: "Indian Circuit",
      history: "Mysore moved between Wodeyar kingship and the military reforms of Haidar Ali and Tipu Sultan, becoming a southern power known for rockets, diplomacy, and palace culture.",
      forts: [
        {
          name: "Srirangapatna Fort",
          about: "Srirangapatna was Tipu Sultan's island capital and a key battlefield in the Anglo-Mysore Wars. Its walls, gates, and dungeons carry the story of Mysore's resistance."
        },
        {
          name: "Chitradurga Fort",
          about: "Chitradurga's seven rings of walls climb through granite hills. It protected central Karnataka and shows how terrain itself became part of the defense."
        },
        {
          name: "Bangalore Fort",
          about: "Bangalore Fort began as a mud fort and later became a stone stronghold under Haidar Ali. British capture of the fort marked a turning point in the Third Anglo-Mysore War."
        }
      ]
    },
    "New Delhi": {
      group: "Indian Circuit",
      history: "Delhi's region has hosted many capitals, from Sultanate cities to Mughal Shahjahanabad and modern New Delhi, leaving a dense record of power changing hands.",
      forts: [
        {
          name: "Red Fort",
          about: "The Red Fort was Shah Jahan's imperial citadel and became a symbol of Mughal authority. Its halls, gardens, and walls later gained national importance in modern India."
        },
        {
          name: "Purana Qila",
          about: "Purana Qila stands on one of Delhi's old settlement mounds. Afghan and Mughal builders shaped the surviving walls, gateways, and mosque."
        },
        {
          name: "Tughlaqabad Fort",
          about: "Tughlaqabad was built as a massive 14th-century fortified city. Its broken ramparts still show the hard, austere style of the Tughlaq dynasty."
        }
      ]
    },
    "Sikh Empire": {
      group: "Indian Circuit",
      history: "The Sikh Empire under Maharaja Ranjit Singh unified Punjab and surrounding regions through disciplined armies, diplomacy, and control of key frontier forts.",
      forts: [
        {
          name: "Lahore Fort",
          about: "Lahore Fort became a major Sikh imperial seat after earlier Mughal glory. Ranjit Singh's court adapted its palaces, gates, and ceremonial spaces."
        },
        {
          name: "Gobindgarh Fort",
          about: "Gobindgarh guarded Amritsar and held the famed Toshakhana treasury. The fort reflects the military and symbolic priorities of Sikh rule."
        },
        {
          name: "Kangra Fort",
          about: "Kangra Fort is one of the Himalaya's great strongholds. Its control mattered to hill states, Mughals, Sikhs, and later the British."
        }
      ]
    },
    "Sikkim": {
      group: "Indian Circuit",
      history: "Sikkim's Namgyal kingdom sat between Himalayan trade routes and powerful neighbors, with monasteries and hill settlements shaping its political identity.",
      forts: [
        {
          name: "Rabdentse Ruins",
          about: "Rabdentse was Sikkim's second capital and now survives as palace and wall remains near Pelling. The ruins show a Himalayan court positioned for defense and ritual authority."
        },
        {
          name: "Tumlong",
          about: "Tumlong served as a later Sikkimese capital before Gangtok. Its remains point to shifting royal centers as politics and terrain changed."
        },
        {
          name: "Damsang Fort",
          about: "Damsang Fort near Kalimpong is linked with Lepcha and Bhutanese frontier history. It represents the fortified edges of the eastern Himalayan world."
        }
      ]
    },
    "Travancore": {
      group: "Indian Circuit",
      history: "Travancore became a strong southern kingdom through maritime trade, temple wealth, military reform, and careful diplomacy along the Kerala coast.",
      forts: [
        {
          name: "Udayagiri Fort",
          about: "Udayagiri Fort was rebuilt under Marthanda Varma and later associated with European military expertise. Its walls and foundry supported Travancore's modernizing army."
        },
        {
          name: "Vattakottai Fort",
          about: "Vattakottai is a seaside fort near Kanyakumari with views of the Western Ghats and the coast. It guarded the southern edge of Travancore's territory."
        },
        {
          name: "Anchuthengu Fort",
          about: "Anchuthengu Fort was an English East India Company post on the Kerala coast. It reflects the maritime pressures Travancore had to balance."
        }
      ]
    },
    "Africa": {
      group: "International Circuit",
      history: "The Africa circuit points to a continent of ancient kingdoms, coastal trade forts, inland stone cities, and colonial-era strongholds that shaped global exchange.",
      forts: [
        {
          name: "Great Zimbabwe",
          about: "Great Zimbabwe was a stone-built medieval capital tied to gold trade and regional power. Its massive dry-stone walls remain among Africa's great archaeological landmarks."
        },
        {
          name: "Fort Jesus",
          about: "Fort Jesus in Mombasa was built by the Portuguese to control Indian Ocean trade. Its later history passed through Omani, local, and British hands."
        },
        {
          name: "Elmina Castle",
          about: "Elmina Castle began as a Portuguese trading post on the Gold Coast. Its history is also tied to the Atlantic slave trade, making it a solemn site of memory."
        }
      ]
    },
    "Amazon": {
      group: "International Circuit",
      history: "The Amazon venue follows river empires, forest trade, and frontier forts built to control navigation, borders, and extraction across a vast basin.",
      forts: [
        {
          name: "Forte do Presepio",
          about: "Forte do Presepio anchored the Portuguese founding of Belem at the mouth of the Amazon. It guarded river access and the early colonial settlement."
        },
        {
          name: "Fort Principe da Beira",
          about: "Fort Principe da Beira was built deep inland to mark Portuguese claims near the Guapore River. Its remote walls speak to border rivalry in the rainforest."
        },
        {
          name: "Fortaleza de Sao Jose de Macapa",
          about: "Macapa's fortress protected the northern Amazon and Atlantic approaches. Its star-shaped plan reflects 18th-century military engineering."
        }
      ]
    },
    "America": {
      group: "International Circuit",
      history: "America's fort story spans Indigenous homelands, Spanish coastal defense, colonial wars, revolution, and civil conflict across a continent of contested frontiers.",
      forts: [
        {
          name: "Castillo de San Marcos",
          about: "This St. Augustine fortress is the oldest masonry fort in the continental United States. Its coquina walls withstood sieges that would have shattered harder stone."
        },
        {
          name: "Fort Ticonderoga",
          about: "Fort Ticonderoga controlled the route between Lake George and Lake Champlain. It changed hands during imperial wars and the American Revolution."
        },
        {
          name: "Fort Sumter",
          about: "Fort Sumter in Charleston Harbor became the opening flashpoint of the American Civil War. Its brick walls became a national symbol of division and reunion."
        }
      ]
    },
    "Arabia": {
      group: "International Circuit",
      history: "Arabia's circuit moves through oasis towns, caravan routes, coastal ports, and desert fortresses that protected trade, dynasties, and tribal alliances.",
      forts: [
        {
          name: "Masmak Fort",
          about: "Masmak Fort in Riyadh is tied to the 1902 recapture that helped launch modern Saudi rule. Its mud-brick towers show Najdi defensive architecture."
        },
        {
          name: "Nizwa Fort",
          about: "Nizwa Fort guarded one of Oman's historic inland capitals. Its huge round tower was designed to dominate the oasis and surrounding approaches."
        },
        {
          name: "Al Jahili Fort",
          about: "Al Jahili Fort in Al Ain protected palm groves and local authority in the oasis. It later became associated with travel, patrols, and desert governance."
        }
      ]
    },
    "Australia": {
      group: "International Circuit",
      history: "Australia's fortifications were shaped by coastal defense, colonial ports, and fears of naval attack, especially around harbors and strategic headlands.",
      forts: [
        {
          name: "Fort Denison",
          about: "Fort Denison sits inside Sydney Harbour and was built as a colonial defensive battery. Its island profile became a familiar part of the harbor landscape."
        },
        {
          name: "Fort Queenscliff",
          about: "Fort Queenscliff protected the entrance to Port Phillip Bay. It formed part of one of Australia's most important coastal defense networks."
        },
        {
          name: "Fort Scratchley",
          about: "Fort Scratchley guarded Newcastle and famously fired on a Japanese submarine in 1942. The site connects colonial defenses with World War II history."
        }
      ]
    },
    "China": {
      group: "International Circuit",
      history: "China's circuit draws from imperial walls, frontier passes, river forts, and port defenses built across centuries of dynastic statecraft and foreign pressure.",
      forts: [
        {
          name: "Jiayuguan Fort",
          about: "Jiayuguan marked the western end of the Ming Great Wall. It controlled Silk Road movement between the Chinese heartland and Central Asia."
        },
        {
          name: "Xi'an City Wall",
          about: "Xi'an's city wall is one of China's best-preserved urban fortifications. It enclosed a former imperial capital with gates, towers, and a broad defensive circuit."
        },
        {
          name: "Humen Forts",
          about: "The Humen Forts defended the Pearl River approach to Guangzhou. They became important during the Opium War, when coastal defense met modern naval power."
        }
      ]
    },
    "Europe": {
      group: "International Circuit",
      history: "Europe's venue spans castles, walled cities, citadels, and border forts built through feudal rivalries, imperial wars, and urban republics.",
      forts: [
        {
          name: "Tower of London",
          about: "The Tower of London began as a Norman fortress and became a royal palace, prison, mint, and armory. Its layered uses mirror English state power."
        },
        {
          name: "Carcassonne",
          about: "Carcassonne's double walls and towers preserve a medieval fortified city in southern France. It shows how urban life and military architecture overlapped."
        },
        {
          name: "Edinburgh Castle",
          about: "Edinburgh Castle sits on a volcanic rock above Scotland's capital. It guarded royal authority and saw repeated sieges during wars over the Scottish crown."
        }
      ]
    },
    "India": {
      group: "International Circuit",
      history: "The global India venue represents the subcontinent's layered fort traditions, from Rajput hill citadels to Mughal imperial seats and Deccan strongholds.",
      forts: [
        {
          name: "Red Fort",
          about: "Delhi's Red Fort was the ceremonial heart of the Mughal Empire. It later became a national stage for independence-era memory and annual addresses."
        },
        {
          name: "Gwalior Fort",
          about: "Gwalior Fort dominates a sandstone plateau and controlled central Indian routes. Rajput, Mughal, Maratha, and British periods all left marks there."
        },
        {
          name: "Chittorgarh Fort",
          about: "Chittorgarh is one of India's largest hill forts and a symbol of Mewar resistance. Its palaces, towers, and reservoirs tell a long Rajput story."
        }
      ]
    },
    "Russia": {
      group: "International Circuit",
      history: "Russia's fort history runs from kremlins and river citadels to Baltic and Pacific defenses, reflecting a state built across immense distances.",
      forts: [
        {
          name: "Moscow Kremlin",
          about: "The Moscow Kremlin is a fortified political and religious center at the heart of Russia. Its walls and towers frame centuries of princely, imperial, Soviet, and modern power."
        },
        {
          name: "Peter and Paul Fortress",
          about: "Peter and Paul Fortress founded St. Petersburg as a Baltic stronghold. It later became a prison and a ceremonial landmark of the imperial capital."
        },
        {
          name: "Vladivostok Fortress",
          about: "Vladivostok Fortress defended Russia's Pacific port with batteries, tunnels, and hill positions. It shows the scale of late imperial military engineering."
        }
      ]
    },
    "Southeast": {
      group: "International Circuit",
      history: "The Southeast circuit follows monsoon trade, island ports, temple cities, and colonial bastions across a region shaped by sea lanes and inland kingdoms.",
      forts: [
        {
          name: "Fort Santiago",
          about: "Fort Santiago guarded Manila's Intramuros district under Spanish rule. Its history includes trade, war, imprisonment, and Philippine national memory."
        },
        {
          name: "Fort Cornwallis",
          about: "Fort Cornwallis in Penang was built by the British East India Company. It protected a strategic port on the Strait of Malacca."
        },
        {
          name: "Hue Imperial City",
          about: "Hue's citadel enclosed the Nguyen dynasty's imperial capital. Its walls, gates, and palaces became central to Vietnam's royal and wartime history."
        }
      ]
    }
  };

  const subVenueNames = {
  "Baroda": [
    "Bhadra Fort (India)",
    "Bhujia Fort (India)",
    "Dhoraji Fort (India)",
    "Diu Fort (India)",
    "Lakhota Fort (India)",
    "Pavagadh Fort (India)",
    "Surat Fort (India)",
    "Uparkot Fort (India)"
  ],
  "Hyderabad": [
    "Bhongir Fort (India)",
    "Golconda Fort (India)",
    "Konda Reddy Fort (India)",
    "Kondapalli Fort (India)",
    "Warangal Fort (India)"
  ],
  "Indore": [
    "Asirgarh Fort (India)",
    "Dhar Fort (India)",
    "Gwalior Fort (India)",
    "Mandu Fort (India)",
    "Narwar Fort (India)"
  ],
  "Jaipur": [
    "Achalgarh Fort (India)",
    "Chittorgarh Fort (India)",
    "Jalore Fort (India)",
    "Junagarh Fort (India)",
    "Kumbhalgarh Fort (India)",
    "Lohagarh Fort (India)",
    "Mehrangarh Fort (India)",
    "Sajjangarh Fort (India)",
    "Taragarh Fort (India)"
  ],
  "Maratha Empire": [
    "Arnala Fort (India)",
    "Lohagad Fort (India)",
    "Pratapgad Fort (India)",
    "Raigad Fort (India)",
    "Shivneri Fort (India)",
    "Sindhudurg Fort (India)",
    "Sinhagad Fort (India)",
    "Vijaydurg Fort (India)"
  ],
  "Mysore": [
    "Bangalore Fort (India)",
    "Chitradurga Fort (India)",
    "Madikeri Fort (India)",
    "Manjarabad Fort (India)",
    "Srirangapatna Fort (India)"
  ],
  "New Delhi": [
    "Adilabad Fort (India)",
    "Agra Fort (India)",
    "Allahabad Fort (India)",
    "Ballabhgarh Fort (India)",
    "Chunar Fort (India)",
    "Firoz Shah Kotla (India)",
    "Panipat Fort (India)",
    "Purana Qila (India)",
    "Ramnagar Fort (India)",
    "Red Fort (India)",
    "Salimgarh Fort (India)",
    "Tughlaqabad Fort (India)"
  ],
  "Sikh Empire": [
    "Attock Fort (Pakistan)",
    "Bahadurgarh Fort (India)",
    "Bahu Fort (India)",
    "Bathinda Fort (India)",
    "Govindgarh Fort (India)",
    "Hari Parbat Fort (India)",
    "Jamrud Fort (Pakistan)",
    "Kangra Fort (India)",
    "Keshgarh Fort (India)",
    "Multan Fort (Pakistan)",
    "Nabha Fort (India)",
    "Nandana Fort (Pakistan)",
    "Payal Fort (India)",
    "Pharwala Fort (Pakistan)",
    "Phillaur Fort (India)",
    "Qila Mubarak Patiala (India)",
    "Rohtas Fort (Pakistan)",
    "Sangni Fort (Pakistan)",
    "Shahpurkandi Fort (India)",
    "Sheikhupura Fort (Pakistan)",
    "Sialkot Fort (Pakistan)"
  ],
  "Sikkim": [
    "Rabdentse (India)",
    "Damsang Fort (India)",
    "Budang Gadi Fort (India)",
    "Buxa Fort (India)",
    "Barabati Fort (India)",
    "Bihu Loukon Fort (India)",
    "Garh Doul (India)",
    "Ita Fort (India)",
    "Kangla Fort (India)",
    "Sisupalgarh (India)"
  ],
  "Travancore": [
    "Dindigul Fort (India)",
    "East Fort (India)",
    "Pallippuram Fort (India)",
    "Tiruchirappalli Rock Fort (India)",
    "Udayagiri Fort (India)",
    "Vattakottai Fort (India)"
  ],
  "Africa": [
    "Bastion de la Sqala (Morocco)",
    "Cairo Citadel (Egypt)",
    "Castle of Good Hope (South Africa)",
    "Fort d’Estrees (Senegal)",
    "Fort Dauphin (Madagascar)",
    "Fort Jesus (Kenya)",
    "Old Fort Durban (South Africa)",
    "Apollonia Fortress (Libya)",
    "Camp Lemonnier (Djibouti)",
    "Fort James / Kunta Kinteh Island (Gambia)"
  ],
  "S. America": [
    "Fort Bueras (Chile)",
    "Fort Copacabana (Brazil)",
    "Fort of Buenos Aires (Argentina)",
    "Itaipu Fortress (Brazil)",
    "Real Felipe Fortress (Peru)",
    "San Felipe de Barajas (Colombia)",
    "Fortaleza de Santa Cruz da Barra (Brazil)",
    "Fortaleza de São José de Macapá (Brazil)"
  ],
  "N. America": [
    "San Juan de Ulúa (Mexico)",
    "Fort Dallas (United States)",
    "Fort Dearborn (United States)",
    "Fort Independence (United States)",
    "Fort McNair (United States)",
    "Fort Point (United States)",
    "Fort Travis (United States)",
    "Fort Wadsworth (United States)",
    "Fort York (Canada)",
    "Old Las Vegas Fort (United States)",
    "Castillo de San Marcos (United States)",
    "Fort Ticonderoga (United States)",
    "Fort George (Belize)",
    "Fort Sumter (United States)",
    "Fort McHenry (United States)",
    "Fort Monroe (United States)",
    "Fort Pulaski (United States)",
    "Fort Moultrie (United States)",
    "Fort Matanzas (United States)",
    "Fort Pickens (United States)",
    "Fort Morgan (United States)",
    "Fort Washington (United States)",
    "Fort Niagara (United States)",
    "Fort Stanwix (United States)",
    "Fort Crown Point (United States)",
    "Fort Pitt (United States)",
    "Fort Necessity (United States)",
    "Fort Frederica (United States)",
    "The Alamo (United States)",
    "Fort Davis (United States)",
    "Fort Concho (United States)",
    "Fort Laramie (United States)",
    "Fort Bridger (United States)",
    "Fort Vancouver (United States)",
    "Fort Clatsop (United States)",
    "Fort Snelling (United States)",
    "Fort Leavenworth (United States)",
    "Fort Sill (United States)",
    "Fort Knox (United States)",
    "Bent’s Old Fort (United States)",
    "Fort Union (United States)",
    "Fort Bowie (United States)",
    "Fort Robinson (United States)"
  ],
  "Arabia": [
    "Al Jalali Fort (Oman)",
    "Al Koot Fort (Qatar)",
    "Asfan Castle (Saudi Arabia)",
    "Bahrain Fort (Bahrain)",
    "Citadel of Damascus (Syria)",
    "Kuwait Red Fort (Kuwait)",
    "Masmak Fort (Saudi Arabia)",
    "Qasr Al Hosn (United Arab Emirates)",
    "Sidon Sea Castle (Lebanon)"
  ],
  "China": [
    "Dapeng Fortress (China)",
    "Juyong Pass Fortress (China)",
    "Weiyuan Fort (China)",
    "Wusong Fortress (China)",
    "Xi’an City Wall (China)",
    "Jiayu Pass Fortress (China)",
    "Shanhai Pass Fortress (China)"
  ],
  "Far East": [
    "Edo Castle (Japan)",
    "Nijo Castle (Japan)",
    "Himeji Castle (Japan)",
    "Osaka Castle (Japan)",
    "Kumamoto Castle (Japan)",
    "Suwon Hwaseong Fortress (South Korea)",
    "Namhansanseong Fortress (South Korea)",
    "Hwaseong Haenggung (South Korea)"
  ],
  "Asia Rest": [
    "Gia Dinh Citadel (Vietnam)",
    "Imperial Citadel of Thang Long (Vietnam)",
    "Longvek Citadel (Cambodia)",
    "Phra Sumen Fort (Thailand)",
    "Rawat Fort (Pakistan)",
    "Mandalay Palace Fort (Myanmar)",
    "Red Fort of Lahore / Lahore Fort (Pakistan)",
    "Bala Hissar Peshawar (Pakistan)"
  ],
  "Central Asia": [
    "Ark of Bukhara (Uzbekistan)",
    "Itchan Kala (Uzbekistan)",
    "Ayaz Kala (Uzbekistan)",
    "Toprak Kala (Uzbekistan)",
    "Kunya-Ark Citadel (Uzbekistan)",
    "Gissar Fortress (Tajikistan)",
    "Hulbuk Fortress (Tajikistan)",
    "Nisa Fortress (Turkmenistan)",
    "Merv Fortifications (Turkmenistan)",
    "Sauran Fortress (Kazakhstan)",
    "Otrar Fortress (Kazakhstan)"
  ],
  "Persia": [
    "Arg-e Bam (Iran)",
    "Rayen Castle (Iran)",
    "Falak-ol-Aflak Castle (Iran)",
    "Narin Castle (Iran)",
    "Shush Castle (Iran)",
    "Erbil Citadel (Iraq)",
    "Al-Ukhaidir Fortress (Iraq)",
    "Kirkuk Citadel (Iraq)"
  ],
  "Europe": [
    "Acropolis of Athens (Greece)",
    "Tower of London (United Kingdom)",
    "Alhambra (Spain)",
    "Edinburgh Castle (United Kingdom)",
    "Windsor Castle (United Kingdom)",
    "Castel Sant’Angelo (Italy)",
    "Carcassonne Citadel (France)",
    "Hohensalzburg Fortress (Austria)",
    "Malbork Castle (Poland)",
    "Bran Castle (Romania)",
    "Suomenlinna Fortress (Finland)",
    "Bellinzona Castles (Switzerland)",
    "Château de Vincennes (France)",
    "Sforza Castle (Italy)",
    "Spandau Citadel (Germany)",
    "Montjuic Castle (Spain)",
    "Kyiv Fortress (Ukraine)"
  ],
  "Britain": [
    "Bodiam Castle (United Kingdom)",
    "Caernarfon Castle (United Kingdom)",
    "Dover Castle (United Kingdom)",
    "Eilean Donan Castle (United Kingdom)",
    "Stirling Castle (United Kingdom)",
    "Caerphilly Castle (United Kingdom)",
    "Bamburgh Castle (United Kingdom)"
  ],
  "France": [
    "Château de Chambord (France)",
    "Fort Boyard (France)",
    "Château de Pierrefonds (France)",
    "Château de Chinon (France)",
    "Château de Fougères (France)",
    "Château de Saumur (France)"
  ],
  "Italy": [
    "Rocca Calascio (Italy)",
    "Castel del Monte (Italy)",
    "Castello di Miramare (Italy)",
    "Castello Estense (Italy)",
    "Castel Nuovo (Italy)",
    "Rocca Maggiore (Italy)"
  ],
  "Spain": [
    "Alcázar of Segovia (Spain)",
    "Manzanares Castle (Spain)",
    "Castillo de Coca (Spain)",
    "Castle of Loarre (Spain)",
    "Castillo de Peñafiel (Spain)",
    "Alcazaba of Málaga (Spain)"
  ],
  "Portugal": [
    "Elvas Fortifications (Portugal)",
    "Guimarães Castle (Portugal)",
    "Pena Palace (Portugal)",
    "Castle of the Moors (Portugal)",
    "Belém Tower (Portugal)",
    "São Jorge Castle (Portugal)"
  ],
  "North Sea": [
    "Fort Pampus (Netherlands)",
    "Muiderslot Castle (Netherlands)",
    "Bourtange Fortress (Netherlands)",
    "Naarden Fortress (Netherlands)",
    "Gravensteen (Belgium)",
    "Bouillon Castle (Belgium)",
    "Bock Casemates (Luxembourg)",
    "Gutenberg Castle (Liechtenstein)"
  ],
  "Scandinavia": [
    "Kronborg Castle (Denmark)",
    "Bohus Fortress (Sweden)",
    "Kalmar Castle (Sweden)",
    "Olavinlinna Castle (Finland)",
    "Vardøhus Fortress (Norway)",
    "Bergenhus Fortress (Norway)",
    "Skansinn Fort (Iceland)"
  ],
  "Baltic Marches": [
    "Kamianets-Podilskyi Castle (Ukraine)",
    "Khotyn Fortress (Ukraine)",
    "Akkerman Fortress (Ukraine)",
    "Brest Fortress (Belarus)",
    "Mir Castle (Belarus)",
    "Nesvizh Castle (Belarus)",
    "Trakai Island Castle (Lithuania)",
    "Narva Castle (Estonia)",
    "Turaida Castle (Latvia)",
    "Kaunas Castle (Lithuania)"
  ],
  "Russia & Siberia": [
    "Moscow Kremlin (Russia)",
    "Peter and Paul Fortress (Russia)",
    "Smolensk Fortress (Russia)",
    "Izborsk Fortress (Russia)",
    "Vladivostok Fortress (Russia)",
    "Tobolsk Kremlin (Russia)",
    "Omsk Fortress (Russia)",
    "Kuznetsk Fortress (Russia)",
    "Naryn-Kala Fortress (Russia)",
    "Derbent Fortress (Russia)"
  ],
  "Mediterranean": [
    "Acrocorinth (Greece)",
    "Palamidi Fortress (Greece)",
    "Castle of Mystras (Greece)",
    "Methoni Castle (Greece)",
    "Rumelihisarı (Turkey)",
    "Yedikule Fortress (Turkey)",
    "Predjama Castle (Slovenia)",
    "Lovrijenac Fortress (Croatia)",
    "Klis Fortress (Croatia)",
    "St. Nicholas Fortress (Croatia)",
    "Kamerlengo Castle (Croatia)",
    "Golubac Fortress (Serbia)",
    "Tsarevets Fortress (Bulgaria)",
    "Fort Antoine (Monaco)",
    "Fort St Elmo (Malta)",
    "Moorish Castle (Gibraltar)",
    "Kyrenia Castle (Cyprus)"
  ],
  "Alaska": [
    "Fort William H. Seward (United States)",
    "Castle Hill / Baranof Castle Site (United States)",
    "Fort Abercrombie (United States)",
    "Fort Egbert (United States)",
    "Fort Davis Nome (United States)",
    "Fort Gibbon (United States)",
    "Camp Century (Greenland)"
  ],
  "Caribbean": [
    "Brimstone Hill Fortress (Saint Kitts and Nevis)",
    "Castillo San Felipe del Morro (United States)",
    "Castillo San Cristóbal (United States)",
    "Castillo de San Pedro de la Roca (Cuba)",
    "Fort Charles (Jamaica)",
    "Fort Charlotte (The Bahamas)",
    "Saint Ann’s Fort (Barbados)",
    "Fort George Grenada (Grenada)",
    "Fort King George Tobago (Trinidad and Tobago)",
    "Fort Shirley (Dominica)"
  ],
  "Dragonland": [
    "Guia Fortress (China)",
    "Monte Fort (China)",
    "Tung Chung Fort (China)",
    "Kowloon Walled City Site (China)",
    "Fort Santo Domingo (Taiwan)",
    "Eternal Golden Castle (Taiwan)",
    "Anping Fort (Taiwan)",
    "Hobe Fort (Taiwan)"
  ],
  "Straits": [
    "Fort Siloso (Singapore)",
    "Fort Canning (Singapore)",
    "Labrador Battery (Singapore)",
    "Johore Battery (Singapore)",
    "Fort Cornwallis (Malaysia)",
    "A Famosa (Malaysia)",
    "Fort Margherita (Malaysia)",
    "Kuala Kedah Fort (Malaysia)",
    "Fort Rotterdam (Indonesia)",
    "Fort Belgica (Indonesia)",
    "Fort Tolukko (Indonesia)",
    "Fort Marlborough (Indonesia)",
    "Kota Batu (Brunei)"
  ],
  "Indian Ocean": [
    "Galle Fort (Sri Lanka)",
    "Jaffna Fort (Sri Lanka)",
    "Batticaloa Fort (Sri Lanka)",
    "Fort Fredrick (Sri Lanka)",
    "Fort Adelaide (Mauritius)",
    "Fort George Mauritius (Mauritius)",
    "Utheemu Ganduvaru (Maldives)",
    "Mulee’aage Palace (Maldives)",
    "Addu Atoll British Loyalty Remains (Maldives)",
    "Fort Victoria Seychelles Site (Seychelles)"
  ],
  "Pacific": [
    "Fort Takapuna (New Zealand)",
    "Fort Ballance (New Zealand)",
    "Fort Jervois (New Zealand)",
    "North Head Historic Reserve (New Zealand)",
    "Tavuni Hill Fort (Fiji)",
    "Fort Apugan (Guam / United States)",
    "Fort Nuestra Señora de la Soledad (Guam / United States)",
    "Fort Santa Agueda (Guam / United States)",
    "Arai-Te-Tonga (Cook Islands)",
    "Peleliu Fortifications (Palau)",
    "Espiritu Santo WWII Base (Vanuatu)"
  ],
  "British Isles": [
    "Fort Barrington (Antigua and Barbuda)",
    "Fort James Antigua (Antigua and Barbuda)",
    "The Garrison (Bermuda)",
    "Fort St. Catherine (Bermuda)",
    "Fort Hamilton (Bermuda)",
    "Fort George Cayman (Cayman Islands)",
    "Fort Burt (British Virgin Islands)",
    "Fort Recovery (British Virgin Islands)",
    "Fort George Montserrat (Montserrat)",
    "High Knoll Fort (Saint Helena)",
    "Peel Castle (Isle of Man)"
  ],
  "French Isles": [
    "Fort Napoléon des Saintes (Guadeloupe / France)",
    "Fort Delgrès (Guadeloupe / France)",
    "Fort Fleur d’Épée (Guadeloupe / France)",
    "Fort Saint Louis (Martinique / France)",
    "Fort Desaix (Martinique / France)",
    "Fort Royal / Fort-de-France (Martinique / France)",
    "Fort Teremba (New Caledonia / France)",
    "Fort de la Reine (Réunion / France)",
    "Dzaoudzi Fortifications (Mayotte / France)",
    "Wallis & Futuna Royal Sites (Wallis and Futuna / France)",
    "Fort Gustaf (Saint Barthelemy)",
    "Fort Taravao (French Polynesia)"
  ],
  "Dutch Isles": [
    "Fort Amsterdam (Curaçao / Netherlands)",
    "Fort Nassau (Curaçao / Netherlands)",
    "Fort Beekenburg (Curaçao / Netherlands)",
    "Fort Oranje Sint Eustatius (Sint Eustatius / Netherlands)",
    "Fort Zoutman (Aruba / Netherlands)",
    "Fort Bay (Saba / Netherlands)",
    "Fort Zeelandia Suriname (Suriname)",
    "Fort Nieuw Amsterdam (Suriname)"
  ],
  "American Isles": [
    "Fort Christian (United States)",
    "Fort Frederik (United States)",
    "Blackbeard’s Castle (United States)",
    "Fort Segarra (United States)",
    "Fort San Jose Guam (Guam / United States)",
    "Fort Kamehameha (United States)",
    "Fort DeRussy (United States)",
    "Fort Armstrong (United States)",
    "Fort Ruger (United States)",
    "Fort Hase (United States)"
  ],
  "Dominion of Canada": [
    "CFB Halifax",
    "CFB Esquimalt",
    "CFB Kingston",
    "CFB Petawawa",
    "CFB Gagetown",
    "CFB Borden",
    "CFB Trenton",
    "CFB Cold Lake",
    "CFB Valcartier"
  ],
  "Massachusetts": [
    "Hanscom Air Force Base",
    "Springfield Armory",
    "Charlestown Navy Yard",
    "Fort Andrews",
    "Fort Revere",
    "Fort Banks",
    "Fort Sewall",
    "Fort Strong",
    "Fort Phoenix",
    "Otis Air National Guard Base"
  ],
  "New York": [
    "West Point Military Academy",
    "Fort Drum",
    "Fort Totten",
    "Fort Montgomery",
    "Fort Clinton",
    "Brooklyn Navy Yard",
    "Watervliet Arsenal",
    "Madison Barracks",
    "Fort Wood",
    "Camp Smith"
  ],
  "Virginia": [
    "Fort Belvoir",
    "Fort Gregg-Adams",
    "Fort Eustis",
    "Fort Story",
    "Fort Myer",
    "Fort Hunt",
    "Norfolk Naval Station",
    "Marine Corps Base Quantico",
    "Joint Base Langley-Eustis",
    "Naval Air Station Oceana"
  ],
  "Illinois": [
    "Rock Island Arsenal",
    "Great Lakes Naval Station",
    "Camp Grant",
    "Camp Lincoln",
    "Fort Sheridan",
    "Fort Massac",
    "Fort de Chartres",
    "Camp Ellis",
    "Fort Crevecoeur",
    "Joliet Army Ammunition Plant"
  ],
  "Florida": [
    "Fort Jefferson",
    "Fort Clinch",
    "Fort Barrancas",
    "Fort Zachary Taylor",
    "Fort Brooke",
    "Naval Air Station Pensacola",
    "Naval Station Mayport",
    "Cape Canaveral Space Force Station",
    "Patrick Space Force Base",
    "Homestead Air Reserve Base"
  ],
  "Texas": [
    "Fort Bliss",
    "Fort Cavazos",
    "Fort Sam Houston",
    "Laughlin Air Force Base",
    "Corpus Christi Naval Air Station",
    "Fort McKavett",
    "Presidio La Bahía",
    "Fort Chadbourne",
    "Fort McIntosh",
    "Fort Stockton"
  ],
  "Kansas": [
    "Fort Riley",
    "Fort Larned",
    "Fort Harker",
    "Fort Wallace",
    "Fort Zarah",
    "Fort Dodge",
    "Camp Funston",
    "Smoky Hill Depot",
    "Fort Mann",
    "Fort Aubrey"
  ],
  "Colorado": [
    "Fort Garland",
    "Fort Logan",
    "Camp Hale",
    "Fort Lyon",
    "Fort Vasquez",
    "Fort St. Vrain",
    "Rocky Mountain Arsenal",
    "Buckley Space Force Base",
    "Fort Sedgwick",
    "Fort Lupton"
  ],
  "California": [
    "Vandenberg Space Force Base",
    "Edwards Air Force Base",
    "China Lake Naval Weapons Station",
    "Camp Pendleton",
    "Fort Irwin",
    "Travis Air Force Base",
    "Naval Base San Diego",
    "Mare Island Naval Shipyard",
    "Moffett Federal Airfield",
    "Lawrence Livermore National Laboratory"
  ]
};

  const venueTitles = {
  "Baroda": "Patel",
  "Hyderabad": "Nizam",
  "Indore": "Subedar",
  "Jaipur": "Rawal",
  "Maratha Empire": "Peshwa",
  "Mysore": "Sultan",
  "New Delhi": "Raja",
  "Sikh Empire": "Zaildar",
  "Sikkim": "Sherpa",
  "Travancore": "Thala",
  "Africa": "Mansa",
  "S. America": "Caudillo",
  "N. America": "Chief",
  "Arabia": "Sheikh",
  "China": "Jiangjun",
  "Far East": "Shogun",
  "Asia Rest": "Mandala",
  "Central Asia": "Emir",
  "Persia": "Shah",
  "Europe": "Duke",
  "Britain": "Baron",
  "France": "Marquis",
  "Italy": "Conte",
  "Spain": "Hidalgo",
  "Portugal": "Infante",
  "North Sea": "Stadtholder",
  "Scandinavia": "Jarl",
  "Baltic Marches": "Hetman",
  "Russia & Siberia": "Ataman",
  "Mediterranean": "Strategos",
  "Alaska": "Chieftain",
  "Caribbean": "Governor",
  "Dragonland": "Taipan",
  "Straits": "Laksamana",
  "Indian Ocean": "Admiral",
  "Pacific": "Tui",
  "British Isles": "Warden",
  "French Isles": "Seigneur",
  "Dutch Isles": "Burgher",
  "American Isles": "Marshal",
  "Dominion of Canada": "Mountie",
  "Massachusetts": "Patriot",
  "New York": "Maccabee",
  "Virginia": "Cavalier",
  "Illinois": "Loopmaster",
  "Florida": "Buccaneer",
  "Texas": "Longhorn",
  "Kansas": "Marshal",
  "Colorado": "Prospector",
  "California": "Rainmaker"
};

  const venueGroups = {
  "Africa": "International Circuit",
  "S. America": "International Circuit",
  "N. America": "International Circuit",
  "Arabia": "International Circuit",
  "China": "International Circuit",
  "Far East": "International Circuit",
  "Asia Rest": "International Circuit",
  "Central Asia": "International Circuit",
  "Persia": "International Circuit",
  "Europe": "International Circuit",
  "Baroda": "Indian Circuit",
  "Hyderabad": "Indian Circuit",
  "Indore": "Indian Circuit",
  "Jaipur": "Indian Circuit",
  "Maratha Empire": "Indian Circuit",
  "Mysore": "Indian Circuit",
  "New Delhi": "Indian Circuit",
  "Sikh Empire": "Indian Circuit",
  "Sikkim": "Indian Circuit",
  "Travancore": "Indian Circuit",
  "Britain": "Euro Circuit",
  "France": "Euro Circuit",
  "Italy": "Euro Circuit",
  "Spain": "Euro Circuit",
  "Portugal": "Euro Circuit",
  "North Sea": "Euro Circuit",
  "Scandinavia": "Euro Circuit",
  "Baltic Marches": "Euro Circuit",
  "Russia & Siberia": "Euro Circuit",
  "Mediterranean": "Euro Circuit",
  "Alaska": "Micro Circuit",
  "Caribbean": "Micro Circuit",
  "Dragonland": "Micro Circuit",
  "Straits": "Micro Circuit",
  "Indian Ocean": "Micro Circuit",
  "Pacific": "Micro Circuit",
  "British Isles": "Micro Circuit",
  "French Isles": "Micro Circuit",
  "Dutch Isles": "Micro Circuit",
  "American Isles": "Micro Circuit",
  "Dominion of Canada": "US Circuit",
  "Massachusetts": "US Circuit",
  "New York": "US Circuit",
  "Virginia": "US Circuit",
  "Illinois": "US Circuit",
  "Florida": "US Circuit",
  "Texas": "US Circuit",
  "Kansas": "US Circuit",
  "Colorado": "US Circuit",
  "California": "US Circuit"
};

  const venueTileSummary = (key) => {
    const count = (subVenueNames[key] || venueInfo[key]?.forts || []).length;
    const fortLabel = count === 1 ? "Fort" : "Forts";
    const title = venueTitles[key] || "N/A";
    return `${count} ${fortLabel}, Title: ${title}`;
  };

  const subVenueThemes = {
    "Baroda": [
      "Gujarati grit, sharp value",
      "Garba nights, snap 3-bets",
      "Diamond hands, no punts",
      "Coastal breeze, cold reads",
      "Bazaari swagger, big pots",
      "Dandiya beats, mean bluffs",
      "Temple calm, river bite",
      "Spice heat, steady pressure",
      "Sea-raid stacks, rejam",
      "Quiet smile, loud overbets",
      "Rail jokes, ruthless value",
      "Gujju reads, roast mode"
    ],
    "Jaipur": [
      "Pink-city bluffs, big pots",
      "Desert reads, dagger jams",
      "Amber vibes, royal value",
      "Rajput pride, no mercy",
      "Sandstorm bluffs incoming",
      "Fort walls, fearless raises",
      "Camel tilt? never heard",
      "Gold bazaar, cold 3-bets",
      "Palace calm, savage river",
      "Rajasthan rail, roast you",
      "Sunset stacks, sharp squeezes",
      "Thar heat, mean barrels",
      "Royal grin, ruthless value"
    ],
    "Hyderabad": [
      "Pearl city pressure cooker",
      "Biryani bluffs, spicy jams",
      "Charminar stare, snap 3-bet",
      "Nizam nerves, cold value",
      "Deccan heat, no brakes",
      "Golconda gold, grind mode",
      "Sultan swagger, shove first",
      "Techie math, brutal lines",
      "Pearls out, claws out",
      "Smile off, pressure on"
    ],
    "Mysore": [
      "Tiger stride, river bite",
      "Palace calm, savage value",
      "Rocket bluffs, boom pots",
      "Coffee reads, cold folds",
      "Silk court, savage shove",
      "Wodeyar swagger, no punts",
      "Royal court, ruthless river",
      "Quiet grin, sharp check-raise",
      "Crown on, pressure on",
      "Patience now, pain later"
    ],
    "Travancore": [
      "Backwater bluffs, easy",
      "Coconut calm, sharp claws",
      "Sea breeze, ruthless river",
      "Temple bells, turn barrels",
      "Spice routes, stack routes",
      "Harbour hustle, hero calls",
      "Southside swagger, no punts",
      "Quiet waves, loud overbets",
      "Palm shade, pressure made",
      "Monsoon mood, mean value"
    ],
    "Indore": [
      "Street-food swagger, shove",
      "Poha polite, river savage",
      "Rajwada grind, clean KO",
      "Malwa mood, mean bluffs",
      "Night markets, nasty squeezes",
      "Quiet laugh, sharp raise",
      "No mercy, only value",
      "Spicy stacks, steady hands",
      "Turn pressure, trophy vibes",
      "Cool face, cruel river"
    ],
    "New Delhi": [
      "Metro timing, savage value",
      "Ring-road rage, rejam",
      "Capital grind, no leaks",
      "Capital bluffs, big pots",
      "Old walls, new overbets",
      "Paperwork? I prefer pots",
      "Courtroom calm, river rage",
      "Deadline pressure, snap 3-bets",
      "Bureaucracy? shove anyway",
      "Street food, street fights",
      "Night lights, mean value",
      "Yamuna chill, river kill",
      "Stare down, stack up",
      "Hero calls, zero fear",
      "Mean reads, clean wins",
      "Only pressure, no pity"
    ],
    "Maratha Empire": [
      "Fort raids, fat stacks",
      "Shivaji swagger, snap KO",
      "Peshwa pressure, no punts",
      "Deccan drums, deep runs",
      "Konkan coast, cold value",
      "Cavalry calm, river cut",
      "Steel nerves, spicy overbets",
      "Quick blade, quick rejam",
      "War cry, value high",
      "Crown on, chaos on",
      "Sunset bluffs, sunset value",
      "Edge forged, chips seized"
    ],
    "Sikh Empire": [
      "Punjab lions, big pots",
      "Khalsa calm, brutal jams",
      "Ranjit roar, no mercy",
      "Nihang mode: all in",
      "Khyber gate, cold squeeze",
      "Dhol beats, tilt deletes",
      "Steel kirpan, river cut",
      "Frontier grit, no punts",
      "Lionheart laughs, sharp value",
      "Honor high, bluff higher",
      "No fear, only pressure",
      "Quick rejam, quicker grin",
      "Royal guard, river hard",
      "Mean stare, clean lines",
      "Hard folds, harder barrels",
      "Valor on, overbet on"
    ],
    "Sikkim": [
      "Mountain zen, mean jams",
      "Snowline calm, savage value",
      "Tea trails, tight folds",
      "Monastery mind, no punts",
      "Ridge reads, river knives",
      "Cloud cover, bluff cover",
      "Thin air, thick stacks",
      "Quiet peaks, loud overbets",
      "Himalayan chill, sharp kill",
      "Calm face, cruel river",
      "Summit swagger, snap call",
      "Trail tough, tilt-proof"
    ],
    "Africa": [
      "Savanna swagger, big swings",
      "Sun heat, cold folds",
      "Lion calm, brutal value",
      "Desert grit, sharp squeezes",
      "Coast breeze, chaos barrels",
      "Ancient kings, modern bluffs",
      "Safari eyes, river knives",
      "Tribal beat, tilt defeat",
      "Dust storms, stack storms",
      "Fearless, fresh overbets",
      "Quiet grin, big pots",
      "Pounce fast, punish faster"
    ],
    "S. America": [
      "Jungle bluffs, river knives",
      "Samba tempo, savage value",
      "Volcano cool, brutal jams",
      "Carnival laughs, cruel lines",
      "Rainforest reads, mean bluffs",
      "Riverboat vibes, rejam",
      "Sunset heat, sharp squeezes",
      "Spice & steel, stack steals",
      "Chaos barrels, clean KOs",
      "Loud rail, lethal river",
      "Wild cards, wilder bets",
      "Tango tilt? never heard"
    ],
    "N. America": [
      "Vegas math, brutal value",
      "Big city, bigger bluffs",
      "Cold coffee, colder 3-bets",
      "Roadtrip grit, rejam",
      "Fast lanes, fearless raises",
      "Showtime bluffs, clean wins",
      "Surf calm, savage river",
      "Grind mode, no mercy",
      "Poker face, punchy bets",
      "Hero calls, meme laughs",
      "No punts, only pressure",
      "Chips up, ego down",
      "Loud crowd, cold folds",
      "All gas, no brakes",
      "Stack snatcher, no sorry",
      "Stacks rise, ego falls"
    ],
    "Arabia": [
      "Dune winds, sharp squeezes",
      "Spice souk, savage value",
      "Falcon eyes, claws out",
      "Caravan calm, river rage",
      "Golden sands, cold reads",
      "Desert heat, mean barrels",
      "Mint tea, murder bluffs",
      "Oasis chill, knife river",
      "Sand cold, stacks colder",
      "Silk routes, stack routes",
      "Crescent moon, cruel jams",
      "Sunrise bluffs, sunset value"
    ],
    "Australia": [
      "Outback laughs, overbets",
      "Ocean chill, savage river",
      "Sunburnt bluffs, big pots",
      "No worries, no punts",
      "Wildlife stare, snap shove",
      "Larrikin grin, mean value",
      "Coral coast, cold squeezes",
      "Desert heat, clean KOs",
      "Boomerang bluffs return",
      "No worries, brutal value"
    ],
    "China": [
      "Dragon discipline, river doom",
      "Silk smooth, sudden shove",
      "Great Wall, greater value",
      "Tea calm, brutal jams",
      "Red lanterns, cold reads",
      "Jade guard, sharp squeezes",
      "Fireworks on the turn",
      "Ancient pride, modern grind",
      "No smile, only value",
      "Quiet court, loud overbets",
      "Emperor mode, no punts",
      "Fortune favors the fearless"
    ],
    "Europe": [
      "Solver chic, no punts",
      "Castle calm, cruel value",
      "Espresso reads, snap 3-bets",
      "Musketeer bluffs, clean wins",
      "Knight code, savage river",
      "High fashion, higher bets",
      "Bank-grade value, no leaks",
      "Cold rain, colder folds",
      "Ancient streets, modern grind",
      "Opera calm, dagger jams",
      "Euro swagger, sharp squeezes",
      "Royal roads, ruthless value",
      "Legends only, no mercy",
      "Tight suits, tighter ranges",
      "No drama, only chips",
      "Math clean, ego gone"
    ],
    "India": [
      "Spice roads, stack roads",
      "Masala mood, sharp bluffs",
      "Bollywood bluffs, big pots",
      "Chai breaks, cold 3-bets",
      "Street eats, savage beats",
      "High peaks, higher pots",
      "Coastal breeze, cruel value",
      "Metro timing, no leaks",
      "Fort vibes, fearless jams",
      "Rail laughs, ruthless value",
      "Desi swagger, clean lines",
      "Underdog energy, big wins",
      "Spice up, stack up",
      "Zero punts, full pressure",
      "Hero calls, legend tales",
      "Desi edge, legend vibes"
    ],
    "Russia": [
      "Winter nerves, brutal jams",
      "Ice veins, cold overbets",
      "Red Army pressure, no punts",
      "Siberian stare, snap shove",
      "Vodka jokes, iron folds",
      "Frozen river, sharp knives",
      "Steel rails, savage value",
      "Tsar mode, no mercy",
      "Blizzard bluffs incoming",
      "Cold hands, hot stacks",
      "Iron curtain, clean lines",
      "Cold edge, colder stare"
    ],
    "Asia": [
      "Monsoon bluffs, ninja steals",
      "Island vibes, savage value",
      "Spice fleet, sharp squeezes",
      "Temple calm, dagger jams",
      "Samurai calm, brutal jams",
      "Tiger grin, mean barrels",
      "Jade guard, no leaks",
      "Night market, nasty CR",
      "Sea lanes, stack raids",
      "Quiet zen, loud overbets",
      "Fast trains, faster 3-bets",
      "Lanterns lit, bluffs hit",
      "Road to glory, no punts",
      "Throne vibes, river knives",
      "Legend tales, chip trails",
      "Zen calm, savage edge"
    ],
    "Amazon": [
      "Jungle bluffs, river knives",
      "Samba tempo, savage value",
      "Volcano cool, brutal jams",
      "Carnival laughs, cruel lines",
      "Rainforest reads, mean bluffs",
      "Riverboat vibes, rejam",
      "Sunset heat, sharp squeezes",
      "Spice & steel, stack steals",
      "Chaos barrels, clean KOs",
      "Loud rail, lethal river",
      "Wild cards, wilder bets",
      "Tango tilt? never heard"
    ],
    "America": [
      "Vegas math, brutal value",
      "Big city, bigger bluffs",
      "Cold coffee, colder 3-bets",
      "Roadtrip grit, rejam",
      "Fast lanes, fearless raises",
      "Showtime bluffs, clean wins",
      "Surf calm, savage river",
      "Grind mode, no mercy",
      "Poker face, punchy bets",
      "Hero calls, meme laughs",
      "No punts, only pressure",
      "Chips up, ego down",
      "Loud crowd, cold folds",
      "All gas, no brakes",
      "Stack snatcher, no sorry",
      "Stacks rise, ego falls"
    ],
    "Southeast": [
      "Monsoon bluffs, ninja steals",
      "Island vibes, savage value",
      "Spice fleet, sharp squeezes",
      "Temple calm, dagger jams",
      "Samurai calm, brutal jams",
      "Tiger grin, mean barrels",
      "Jade guard, no leaks",
      "Night market, nasty CR",
      "Sea lanes, stack raids",
      "Quiet zen, loud overbets",
      "Fast trains, faster 3-bets",
      "Lanterns lit, bluffs hit",
      "Road to glory, no punts",
      "Throne vibes, river knives",
      "Legend tales, chip trails",
      "Zen calm, savage edge"
    ]
  };

  const fallbackSubVenueThemes = [
    "All-in energy",
    "Value town vibes",
    "Bluff city",
    "No punts allowed",
    "River knives",
    "Cold 3-bets",
    "Stack raids",
    "Clean lines, mean wins"
  ];

  const fnv1a32 = (value) => {
    let hash = 0x811c9dc5;
    for (let i = 0; i < value.length; i += 1) {
      hash ^= value.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    return hash >>> 0;
  };

  const subVenueAbout = (kingdomName, subVenueName) => {
    const themes = subVenueThemes[kingdomName] || fallbackSubVenueThemes;
    const list = themes.length ? themes : fallbackSubVenueThemes;
    const seed = fnv1a32(`${kingdomName}|${subVenueName}`);
    return list[seed % list.length];
  };

  const normalizeVenueName = (name) => {
    const clean = (name || "").trim();
    return clean === "India (Global)" ? "India" : clean;
  };

  const venueSlug = (name) =>
    normalizeVenueName(name).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");

  const openVenueDetails = (venueName, updateHash = true) => {
    const key = normalizeVenueName(venueName);
    const info = venueInfo[key] || {
      group: venueGroups[key] || "Circuit",
      history: `${key} is configured as an in-game kingdom in the ${venueGroups[key] || "current circuit"}, with its fort ladder drawn from the live game data.`
    };
    if (!DOM.venueModal) return;

    DOM.venueModalGroup.textContent = info.group;
    const subVenues = subVenueNames[key] || (info.forts || []).map((fort) => fort.name);
    DOM.venueModalTitle.textContent = `${key} sub-venues and forts`;
    DOM.venueModalHistory.textContent = `${info.history} Listed below are the actual in-game sub-venues configured for this kingdom.`;
    DOM.venueFortList.innerHTML = "";

    subVenues.forEach((subVenueName, index) => {
      const item = document.createElement("article");
      item.className = "venue-fort-item";
      const title = document.createElement("h3");
      title.textContent = `${String(index + 1).padStart(2, "0")}. ${subVenueName}`;
      const about = document.createElement("p");
      about.textContent = `In-game sub-venue under ${key}. ${subVenueAbout(key, subVenueName)}.`;
      item.append(title, about);
      DOM.venueFortList.appendChild(item);
    });

    toggleModal(DOM.venueModal, true);
    if (updateHash) {
      window.history.pushState(null, "", `#forts-${venueSlug(key)}`);
    }
  };

  const setupVenueCards = () => {
    document.querySelectorAll(".venue-card").forEach((card) => {
      const heading = card.querySelector("h4");
      const key = normalizeVenueName(heading?.textContent);
      const info = venueInfo[key] || {
        group: venueGroups[key] || "Circuit",
        history: `${key} is configured as an in-game kingdom in the ${venueGroups[key] || "current circuit"}, with its fort ladder drawn from the live game data.`
      };
      const summary = card.querySelector(".venue-card-body p");
      if (summary) summary.textContent = venueTileSummary(key);

      card.tabIndex = 0;
      card.setAttribute("role", "link");
      card.setAttribute("aria-label", `Open sub-venues and forts for ${key}`);
      card.dataset.venue = key;
      card.dataset.href = `#forts-${venueSlug(key)}`;

      if (!card.querySelector(".venue-card-history")) {
        const overlay = document.createElement("div");
        overlay.className = "venue-card-history";
        const text = document.createElement("p");
        text.textContent = info.history;
        const cta = document.createElement("span");
        cta.className = "venue-card-cta";
        cta.textContent = "Open sub-venue list";
        overlay.append(text, cta);
        card.appendChild(overlay);
      }

      card.addEventListener("click", () => openVenueDetails(key));
      card.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          openVenueDetails(key);
        }
      });
    });
  };

  document.addEventListener("click", (event) => {
    const inPopup = [DOM.aboutPopup, DOM.supportPopup].some(p => p.contains(event.target));
    const inTrigger = ["aboutLink", "supportLink"].includes(event.target.id);
    if (!inPopup && !inTrigger) {
      [DOM.aboutPopup, DOM.supportPopup].forEach(p => toggleModal(p, false));
    }
  });

  const venueTabs = document.querySelectorAll(".venue-tab");
  const venueGrids = document.querySelectorAll(".venue-grid");
  const leaderboardItems = document.querySelectorAll(".venue-tab-item");
  const leaderboardTimers = new WeakMap();
  const closeLeaderboardMenu = (item) => {
    if (!item) return;
    clearTimeout(leaderboardTimers.get(item));
    item.classList.remove("leaderboard-open");
    const tab = item.querySelector(".venue-tab");
    if (tab) tab.setAttribute("aria-expanded", "false");
  };
  const openLeaderboardMenu = (item) => {
    if (!item) return;
    leaderboardItems.forEach(other => {
      if (other !== item) closeLeaderboardMenu(other);
    });
    clearTimeout(leaderboardTimers.get(item));
    item.classList.add("leaderboard-open");
    const tab = item.querySelector(".venue-tab");
    if (tab) tab.setAttribute("aria-expanded", "true");
    leaderboardTimers.set(
      item,
      setTimeout(() => closeLeaderboardMenu(item), 3000)
    );
  };
  const setVenueGroup = (target) => {
    venueTabs.forEach(tab => {
      const isActive = tab.dataset.target === target;
      tab.classList.toggle("active", isActive);
      tab.setAttribute("aria-selected", isActive);
    });
    venueGrids.forEach(grid => {
      const isMatch = grid.dataset.group === target;
      grid.classList.toggle("active", isMatch);
    });
  };
  if (venueTabs.length) {
    venueTabs.forEach(tab => {
      const item = tab.closest(".venue-tab-item");
      tab.setAttribute("aria-haspopup", "true");
      tab.setAttribute("aria-expanded", "false");
      tab.addEventListener("click", () => {
        setVenueGroup(tab.dataset.target);
        openLeaderboardMenu(item);
      });
      tab.addEventListener("mouseenter", () => openLeaderboardMenu(item));
      tab.addEventListener("focus", () => openLeaderboardMenu(item));
    });
    // ensure default
    setVenueGroup(document.querySelector(".venue-tab.active")?.dataset.target || "euro");
  }
  setupVenueCards();

  const formatAuraText = (aura) => {
    const rounded = Math.round(aura * 10) / 10;
    return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
  };

  const cleanLeaderboardName = (raw) => {
    const name = String(raw || "").trim();
    return name ? name.slice(0, 40) : "Player";
  };

  const renderLiveLeaderboards = (entries, statusMessage = "") => {
    const liveEntries = entries
      .filter(entry => Number.isFinite(entry.aura) && entry.aura > 0 && entry.name)
      .sort((a, b) => b.aura - a.aura)
      .slice(0, 10);

    document.querySelectorAll(".venue-leaderboard-menu").forEach(menu => {
      menu.querySelectorAll("li:not(.venue-leaderboard-heading)").forEach(row => row.remove());
      if (liveEntries.length === 0) {
        const status = document.createElement("li");
        status.className = "venue-leaderboard-status";
        const message = document.createElement("span");
        message.textContent = statusMessage || "No published rankings yet.";
        const value = document.createElement("strong");
        value.textContent = "—";
        status.append(message, value);
        menu.appendChild(status);
        return;
      }

      liveEntries.forEach((entry, index) => {
        const row = document.createElement("li");
        row.dataset.source = "live";
        const name = document.createElement("span");
        name.textContent = `${index + 1}. ${entry.name}`;
        const aura = document.createElement("strong");
        aura.textContent = `${formatAuraText(entry.aura)} AURA`;
        row.append(name, aura);
        menu.appendChild(row);
      });
    });
  };

  const loadAuraLeaderboards = async () => {
    if (!db) {
      renderLiveLeaderboards([], "Live rankings are unavailable.");
      return;
    }
    try {
      const snap = await db
        .collection("leaderboard")
        .orderBy("auraMilli", "desc")
        .limit(10)
        .get();
      const entries = snap.docs.map(doc => {
        const data = doc.data() || {};
        const legacyAura = Number(data.aura);
        const auraMilli = Number.isFinite(Number(data.auraMilli))
          ? Number(data.auraMilli)
          : (Number.isFinite(legacyAura) ? legacyAura * 1000 : 0);
        return {
          name: cleanLeaderboardName(data.displayName || data.username),
          aura: auraMilli / 1000
        };
      });
      renderLiveLeaderboards(entries);
    } catch (err) {
      console.warn("Leaderboard fetch skipped.", err);
      renderLiveLeaderboards([], "Live rankings are temporarily unavailable.");
    }
  };

  loadAuraLeaderboards();

  const openVenueFromHash = () => {
    const match = window.location.hash.match(/^#forts-(.+)$/);
    if (!match) return;
    const entry = Object.keys(venueInfo).find((name) => venueSlug(name) === match[1]);
    if (entry) openVenueDetails(entry, false);
  };
  openVenueFromHash();
  window.addEventListener("hashchange", openVenueFromHash);

  DOM.editProfileBtn?.addEventListener("click", () => {
    const isVisible = DOM.editProfileForm.style.display === "block";
    DOM.editProfileForm.style.display = isVisible ? "none" : "block";
    DOM.editProfileBtn.innerText = isVisible ? "Edit Profile" : "Cancel Edit";

    if (!isVisible) {
      ["Username", "Email", "Kingdom"].forEach(field => {
        document.getElementById(`edit${field}`).value = document.getElementById(`profile${field}`).innerText;
      });
      document.getElementById("editAbout").value = document.getElementById("dashboardAbout").innerText;
    }
  });

  DOM.editProfileForm?.addEventListener("submit", async (e) => {
    e.preventDefault();

    if (!auth || !auth.currentUser) {
      alert("Please login first.");
      return;
    }

    const user = auth.currentUser;
    const updated = {
      username: document.getElementById("editUsername").value.trim(),
      email: document.getElementById("editEmail").value.trim(),
      kingdom: document.getElementById("editKingdom").value.trim(),
      about: document.getElementById("editAbout").value.trim()
    };

    try {
      if (
        updated.username &&
        updated.username !== (user.displayName || "")
      ) {
        await user.updateProfile({ displayName: updated.username });
      }

      if (
        updated.email &&
        user.email &&
        updated.email.toLowerCase() !== user.email.toLowerCase()
      ) {
        alert("Email change isn’t supported here yet.");
      }

      writeExtraProfile(user.uid, {
        kingdom: updated.kingdom,
        about: updated.about
      });
      if (db) {
        await db.collection("users").doc(user.uid).set({
          email: user.email || updated.email,
          username: updated.username,
          displayName: updated.username,
          kingdom: updated.kingdom,
          about: updated.about.slice(0, 30),
          profileComplete: Boolean(updated.username && updated.kingdom),
          schemaVersion: 1,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }

      await loadProfile(user);
      DOM.editProfileForm.style.display = "none";
      DOM.editProfileBtn.innerText = "Edit Profile";
      alert("Profile updated.");
    } catch (e2) {
      alert(firebaseErrorMessage(e2));
    }
  });

  document.getElementById("registerForm").addEventListener("submit", async e => {
    e.preventDefault();
    try {
      if (!auth) {
        alert("Auth is not available yet. Please refresh and try again.");
        return;
      }

      const email = document.getElementById("registerEmail").value.trim();
      const password = document.getElementById("registerPassword").value;
      const confirm = document.getElementById("confirmPassword").value;
      const username = document.getElementById("registerUsername").value.trim();
      const kingdom = document.getElementById("registerKingdom").value.trim();
      const about = document.getElementById("aboutUser").value.trim();

      if (password !== confirm) {
        alert("Passwords do not match.");
        return;
      }

      const cred = await auth.createUserWithEmailAndPassword(email, password);
      const user = cred.user;
      if (user && username) {
        await user.updateProfile({ displayName: username });
      }
      if (user) {
        writeExtraProfile(user.uid, { kingdom, about });
        if (db) {
          try {
            await db.collection("users").doc(user.uid).set({
              email,
              username,
              displayName: username,
              kingdom,
              about: about.slice(0, 30),
              profileComplete: Boolean(username && kingdom),
              schemaVersion: 1,
              createdAt: firebase.firestore.FieldValue.serverTimestamp(),
              updatedAt: firebase.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
          } catch (profileError) {
            console.warn("Profile sync will retry in the app.", profileError);
          }
        }
      }

      alert("Registered successfully.");
      if (user) await loadProfile(user);
      document.getElementById("closeModal").click();
    } catch (err) {
      alert(firebaseErrorMessage(err));
    }
  });

  document.getElementById("loginForm").addEventListener("submit", async e => {
    e.preventDefault();
    try {
      if (!auth) {
        alert("Auth is not available yet. Please refresh and try again.");
        return;
      }

      const email = document.getElementById("loginEmail").value.trim();
      const password = document.getElementById("loginPassword").value;
      const cred = await auth.signInWithEmailAndPassword(email, password);
      if (cred.user) await loadProfile(cred.user);
      document.getElementById("closeModal").click();
    } catch (err) {
      alert(firebaseErrorMessage(err));
    }
  });

  document.getElementById("logoutBtn").addEventListener("click", () => {
    if (!auth) {
      loadProfile(null);
      toggleModal(DOM.profileModal, false);
      return;
    }
    auth.signOut().finally(() => {
      loadProfile(null);
      toggleModal(DOM.profileModal, false);
      alert("You have been logged out.");
    });
  });

  const forgotPasswordLink = document.getElementById("forgotPasswordLink");
  if (forgotPasswordLink) {
    forgotPasswordLink.addEventListener("click", async (e) => {
      e.preventDefault();
      const email = document.getElementById("loginEmail").value;
      if (!email) return alert("Please enter your email first.");
      try {
        if (!auth) {
          alert("Auth is not available yet. Please refresh and try again.");
          return;
        }
        await auth.sendPasswordResetEmail(email.trim());
        alert("Password reset email sent.");
      } catch (err) {
        alert(firebaseErrorMessage(err));
      }
    });
  }

  const setDashboardValue = (id, value) => {
    const element = document.getElementById(id);
    if (element) element.innerText = String(value);
  };

  const setDashboardUnavailable = () => {
    [
      "dashboardFortWins",
      "dashboardKingdomWins",
      "dashboardCircuitWins",
      "dashboardTitlesWon",
      "dashboardAura",
      "dashboardAupTotal",
      "dashboardAupLeft",
      "dashboardAupOceania",
      "dashboardAupEuro",
      "dashboardAupIndia",
      "dashboardAupInternational",
      "dashboardAupNorthAmerica"
    ].forEach(id => setDashboardValue(id, "—"));
  };

  async function loadProfile(user) {
    const isSignedIn = Boolean(user);
    const logoutBtn = document.getElementById("logoutBtn");
    if (logoutBtn) logoutBtn.style.display = isSignedIn ? "" : "none";
    if (DOM.editProfileBtn) DOM.editProfileBtn.style.display = isSignedIn ? "" : "none";
    if (profileIconLink) {
      profileIconLink.setAttribute(
        "aria-label",
        isSignedIn ? "Open my profile" : "Sign in to manage profile",
      );
    }
    if (dashboardIconLink) {
      dashboardIconLink.setAttribute("aria-label", "Open player dashboard");
    }

    if (!isSignedIn) {
      if (DOM.editProfileForm) DOM.editProfileForm.style.display = "none";
    }

    if (user) {
      const extra = user.uid ? readExtraProfile(user.uid) : {};
      let remoteProfile = {};
      let progress = null;
      if (db) {
        try {
          const [profileSnap, progressSnap] = await Promise.all([
            db.collection("users").doc(user.uid).get(),
            db.collection("server_progress").doc(user.uid).get()
          ]);
          if (!auth || auth.currentUser?.uid !== user.uid) return;
          remoteProfile = profileSnap.exists ? (profileSnap.data() || {}) : {};
          progress = progressSnap.exists ? (progressSnap.data() || {}) : {};
        } catch (error) {
          console.warn("Authoritative player dashboard is unavailable.", error);
        }
      }

      const username = remoteProfile.displayName || user.displayName || extra.username || "Player";
      const email = user.email || "—";
      const kingdom = remoteProfile.kingdom || extra.kingdom || "Not Set";
      const about = remoteProfile.about || extra.about || "Ready to win!";
      const avatarUrl = user.photoURL || "Renoir.png";
      const joined = user.metadata && user.metadata.creationTime
        ? new Date(user.metadata.creationTime).toLocaleDateString(undefined, {
            year: "numeric",
            month: "short",
            day: "numeric"
          })
        : "Joined";

      document.getElementById("profileUsername").innerText = username;
      document.getElementById("profileEmail").innerText = email;
      document.getElementById("profileKingdom").innerText = kingdom;
      document.getElementById("dashboardAbout").innerText = about;
      document.getElementById("dashboardJoined").innerText = joined;
      writeExtraProfile(user.uid, { username, kingdom, about });

      if (progress == null) {
        setDashboardUnavailable();
      } else {
        const indiaAup = Math.max(0, Number(progress.indiaAup) || 0);
        const internationalAup = Math.max(0, Number(progress.internationalAup) || 0);
        const euroAup = Math.max(0, Number(progress.euroAup) || 0);
        const oceaniaAup = Math.max(0, Number(progress.oceaniaAup) || 0);
        const northAmericaAup = Math.max(0, Number(progress.northAmericaAup) || 0);
        const totalAup = indiaAup + internationalAup + euroAup + oceaniaAup + northAmericaAup;
        const maxAup = 1000000000;
        const aura = Math.max(0, Math.min(100, (totalAup / maxAup) * 100));
        const aupLeft = Math.max(0, maxAup - totalAup);
        const cleared = Array.isArray(progress.cleared) ? progress.cleared : [];
        const mainEvents = Array.isArray(progress.mainEventsCleared)
          ? progress.mainEventsCleared
          : [];
        const titlesByCircuit = new Map();
        mainEvents.forEach(id => {
          const group = String(id).split(":")[1] || "";
          if (group) titlesByCircuit.set(group, (titlesByCircuit.get(group) || 0) + 1);
        });
        const circuitsCleared = ["india", "international", "euro", "oceania", "northAmerica"]
          .filter(group => (titlesByCircuit.get(group) || 0) >= 10)
          .length;

        setDashboardValue("dashboardFortWins", cleared.length);
        setDashboardValue("dashboardKingdomWins", mainEvents.length);
        setDashboardValue("dashboardCircuitWins", circuitsCleared);
        setDashboardValue("dashboardTitlesWon", mainEvents.length);
        setDashboardValue("dashboardAura", Math.round(aura));
        setDashboardValue("dashboardAupTotal", totalAup.toLocaleString());
        setDashboardValue("dashboardAupLeft", aupLeft.toLocaleString());
        setDashboardValue("dashboardAupOceania", oceaniaAup.toLocaleString());
        setDashboardValue("dashboardAupEuro", euroAup.toLocaleString());
        setDashboardValue("dashboardAupIndia", indiaAup.toLocaleString());
        setDashboardValue("dashboardAupInternational", internationalAup.toLocaleString());
        setDashboardValue("dashboardAupNorthAmerica", northAmericaAup.toLocaleString());
      }

      const avatarEl = document.getElementById("profileAvatar");
      if (avatarEl) avatarEl.src = avatarUrl;
    } else {
      document.getElementById("profileUsername").innerText = "Guest";
      document.getElementById("profileEmail").innerText = "Not signed in";
      document.getElementById("profileKingdom").innerText = "Not Set";
      document.getElementById("dashboardAbout").innerText = "Ready to win!";
      document.getElementById("dashboardJoined").innerText = "Guest session";
      setDashboardUnavailable();

      const avatarEl = document.getElementById("profileAvatar");
      if (avatarEl) avatarEl.src = "Renoir.png";
    }
  }

  function bindAuthState() {
    if (!auth) {
      loadProfile(null);
      return;
    }
    auth.onAuthStateChanged((u) => loadProfile(u));
  }

  bindAuthState();
});
