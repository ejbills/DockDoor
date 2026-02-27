// DockDoor Website JavaScript

// Fraud warning banner
(function() {
    var banner = document.createElement('div');
    banner.id = 'fraud-banner';
    banner.style.cssText = 'position:sticky;top:0;z-index:10000;background:#1a0608;border-bottom:1.5px solid #ff453a;padding:14px 24px;text-align:center;font-size:14px;color:rgba(255,255,255,0.9);letter-spacing:-0.01em;line-height:1.5;';
    banner.innerHTML = '<strong style="color:#ff453a">Warning:</strong> A fraudulent copy of DockDoor is being sold on the Mac App Store by "\u9a73\u519b \u674e." DockDoor is free and always will be\u200a—\u200aget it on <a href="https://github.com/ejbills/DockDoor" style="color:#2997ff;text-decoration:underline" target="_blank" rel="noopener">GitHub</a>. Already paid? <a href="https://support.apple.com/en-us/118223" style="color:#2997ff;text-decoration:underline" target="_blank" rel="noopener">Request a refund from Apple</a>.';
    document.body.prepend(banner);
    var header = document.querySelector('header');
    if (header) {
        var sync = function() { header.style.top = banner.offsetHeight + 'px'; };
        sync();
        window.addEventListener('resize', sync);
    }
})();

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    // Mobile menu toggle
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const navLinks = document.querySelector('.nav-links');
    
    mobileMenuBtn.addEventListener('click', () => {
        navLinks.classList.toggle('active');
    });
    
    // Close mobile menu when clicking on a link
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', () => {
            navLinks.classList.remove('active');
        });
    });
    
    // Slideshow functionality for customization sections
    function setupSlideshow(slideshowId) {
        const slideshow = document.getElementById(slideshowId);
        if (!slideshow) return;
        
        const track = slideshow.querySelector('.slideshow-track');
        const slides = slideshow.querySelectorAll('.slideshow-slide');
        const indicators = slideshow.querySelectorAll('.slideshow-indicator');
        const prevBtn = slideshow.querySelector('[data-direction="prev"]');
        const nextBtn = slideshow.querySelector('[data-direction="next"]');
        
        let currentIndex = 0;
        const slideCount = slides.length;
        
        // Initialize
        updateSlidePosition();
        updateIndicators();
        
        // Previous slide button
        prevBtn.addEventListener('click', () => {
            currentIndex = (currentIndex - 1 + slideCount) % slideCount;
            updateSlidePosition();
            updateIndicators();
        });
        
        // Next slide button
        nextBtn.addEventListener('click', () => {
            currentIndex = (currentIndex + 1) % slideCount;
            updateSlidePosition();
            updateIndicators();
        });
        
        // Indicator buttons
        indicators.forEach((indicator, index) => {
            indicator.addEventListener('click', () => {
                currentIndex = index;
                updateSlidePosition();
                updateIndicators();
            });
        });
        
        // Auto advance
        let interval = setInterval(() => {
            currentIndex = (currentIndex + 1) % slideCount;
            updateSlidePosition();
            updateIndicators();
        }, 4000);
        
        // Pause on hover
        slideshow.addEventListener('mouseenter', () => {
            clearInterval(interval);
        });
        
        // Resume on mouse leave
        slideshow.addEventListener('mouseleave', () => {
            interval = setInterval(() => {
                currentIndex = (currentIndex + 1) % slideCount;
                updateSlidePosition();
                updateIndicators();
            }, 4000);
        });
        
        // Update slide position
        function updateSlidePosition() {
            track.style.transform = `translateX(-${currentIndex * 100}%)`;
        }
        
        // Update indicators
        function updateIndicators() {
            indicators.forEach((indicator, index) => {
                if (index === currentIndex) {
                    indicator.classList.add('active');
                } else {
                    indicator.classList.remove('active');
                }
            });
        }
    }
    
    // Set up all slideshows
    setupSlideshow('window-switcher-slideshow');
    setupSlideshow('dock-preview-slideshow');
    
    // Video playback controls
    function handleVideoPlayback() {
        const videos = document.querySelectorAll('video');
        
        if ('IntersectionObserver' in window) {
            const videoObserver = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.play();
                    } else {
                        entry.target.pause();
                    }
                });
            }, { threshold: 0.5 });
            
            videos.forEach(video => {
                videoObserver.observe(video);
            });
        } else {
            // Fallback for browsers that don't support IntersectionObserver
            videos.forEach(video => {
                video.play();
            });
        }
    }
    
    // Initialize video playback
    handleVideoPlayback();
    
    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            if (targetId === '#') return;
            
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 80, // Adjust for header height
                    behavior: 'smooth'
                });
            }
        });
    });

    // Animation for elements when scrolling into view
    function animateOnScroll() {
        const elements = document.querySelectorAll('.feature-media-container, .special-feature-card, .customization-card, .settings-card, .large-preview-container, .comments-container, .download-card');
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.1 });
        
        elements.forEach(element => {
            element.style.opacity = '0';
            element.style.transform = 'translateY(20px)';
            element.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
            observer.observe(element);
        });
    }
    
    // Initialize animations on scroll
    if ('IntersectionObserver' in window) {
        animateOnScroll();
    }

    // Donation Modal Logic
    const donationModal = document.getElementById('donation-modal');
    const donationLinks = document.querySelectorAll('.donation-prompt');
    const closeModalBtn = donationModal.querySelector('.modal-close');
    const proceedToDownloadBtn = document.getElementById('proceed-to-download');
    let downloadUrl = '';

    const openModal = () => {
        donationModal.classList.add('active');
        document.body.style.overflow = 'hidden';
    };

    const closeModal = () => {
        donationModal.classList.remove('active');
        document.body.style.overflow = '';

        // Show donation toast after closing modal if no other toast is visible
        if (!document.querySelector('.toast.show')) {
            createToast();
        }
    };

    donationLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            downloadUrl = this.href;
            openModal();
        });
    });

    closeModalBtn.addEventListener('click', closeModal);

    proceedToDownloadBtn.addEventListener('click', function(e) {
        e.preventDefault();
        closeModal();
        window.location.href = downloadUrl;
    });

    donationModal.addEventListener('click', function(e) {
        if (e.target === this) {
            closeModal();
        }
    });

    // Close modal with Escape key
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' && donationModal.classList.contains('active')) {
            closeModal();
        }
    });

    // Toast notification for donations when clicking download buttons
    function createToast() {
        const toastContainer = document.querySelector('.toast-container');
        
        // Create toast HTML
        const toast = document.createElement('div');
        toast.className = 'toast';
        toast.innerHTML = `
            <div class="toast-content">
                <div class="toast-title">
                    <img src="./resources/svg/toastBell.svg" alt="Bell icon" width="20" height="20">
                    Support DockDoor Development
                </div>
                <div class="toast-message">
                    DockDoor is free, but your support helps us continue development. Consider making a small donation to keep this project going.
                </div>
                <div class="toast-actions">
                    <a href="donate.html" class="btn btn-primary toast-btn">Donate</a>
                    <button class="btn btn-secondary toast-btn not-now">Not Now</button>
                </div>
            </div>
        `;
        
        // Add to container
        toastContainer.appendChild(toast);
        
        // Show the toast after a small delay
        setTimeout(() => {
            toast.classList.add('show');
        }, 100);
        
        // Handle "Not Now" button click
        const notNowBtn = toast.querySelector('.not-now');
        notNowBtn.addEventListener('click', () => {
            hideToast(toast);
        });
        
        // Auto hide after 10 seconds
        setTimeout(() => {
            hideToast(toast);
        }, 10000);
    }
    
    function hideToast(toast) {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.remove();
        }, 500);
    }
    
    // Add click event listeners to download buttons
    const downloadButtons = document.querySelectorAll('.download-btn');
    downloadButtons.forEach(button => {
        button.addEventListener('click', (e) => {
            // Don't prevent default - we want the download to happen
        });
    });
    
    // LookieLoo section animations
    function animateLookielooSection() {
        const lookielooFeatures = document.querySelectorAll('.lookieloo-feature');
        const lookielooShowcase = document.querySelector('.lookieloo-showcase');
        
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                    observer.unobserve(entry.target);
                }
            });
        }, { threshold: 0.1 });
        
        // Animate features with staggered delay
        lookielooFeatures.forEach((feature, index) => {
            feature.style.opacity = '0';
            feature.style.transform = 'translateY(30px)';
            feature.style.transition = `opacity 0.6s ease ${index * 0.2}s, transform 0.6s ease ${index * 0.2}s`;
            observer.observe(feature);
        });
        
        // Animate showcase
        if (lookielooShowcase) {
            lookielooShowcase.style.opacity = '0';
            lookielooShowcase.style.transform = 'translateY(30px)';
            lookielooShowcase.style.transition = 'opacity 0.6s ease 0.4s, transform 0.6s ease 0.4s';
            observer.observe(lookielooShowcase);
        }
    }
    
    // Initialize LookieLoo animations
    if ('IntersectionObserver' in window) {
        animateLookielooSection();
    }
    
    // Privacy Policy Modal Logic
    const privacyModal = document.getElementById('privacy-modal');
    const privacyPolicyLink = document.querySelector('.privacy-policy-link');
    const privacyCloseButtons = document.querySelectorAll('.privacy-modal-close');

    if (privacyPolicyLink && privacyModal) {
        privacyPolicyLink.addEventListener('click', (e) => {
            e.preventDefault();
            privacyModal.classList.add('active');
        });

        privacyCloseButtons.forEach(button => {
            button.addEventListener('click', () => {
                privacyModal.classList.remove('active');
            });
        });

        // Close modal when clicking outside
        privacyModal.addEventListener('click', (e) => {
            if (e.target === privacyModal) {
                privacyModal.classList.remove('active');
            }
        });
    }

    // Press carousel infinite scroll
    const pressCarousel = document.querySelector('.press-carousel');
    const pressTrack = document.querySelector('.press-track');

    if (pressCarousel && pressTrack) {
        let scrollTimeout;
        let isUserScrolling = false;
        let animationFrame;
        let scrollPosition = 0;
        const scrollSpeed = 0.4; // pixels per frame
        let halfWidth = 0;

        // Calculate the width of half the track (original content)
        const calculateHalfWidth = () => {
            const items = pressTrack.querySelectorAll('.press-item');
            const itemCount = items.length / 2; // Divided by 2 because we have duplicates
            let width = 0;

            for (let i = 0; i < itemCount; i++) {
                width += items[i].offsetWidth;
            }

            // Add gaps between items
            const gap = parseFloat(getComputedStyle(pressTrack).gap) || 64; // 4rem = 64px fallback
            width += gap * itemCount; // Total gaps including after last item

            return width;
        };

        // Wait for images/content to load, then calculate
        setTimeout(() => {
            halfWidth = calculateHalfWidth();
        }, 100);

        // Mouse drag to scroll functionality
        let isDown = false;
        let startX, startScrollLeft;

        pressCarousel.addEventListener('mousedown', (e) => {
            isDown = true;
            isUserScrolling = true;
            startX = e.pageX - pressCarousel.offsetLeft;
            startScrollLeft = pressCarousel.scrollLeft;
            pressCarousel.style.cursor = 'grabbing';
        });

        const stopDragging = () => {
            isDown = false;
            pressCarousel.style.cursor = 'grab';
        };

        pressCarousel.addEventListener('mouseup', stopDragging);
        pressCarousel.addEventListener('mouseleave', stopDragging);

        pressCarousel.addEventListener('mousemove', (e) => {
            if (!isDown) return;
            e.preventDefault();
            const x = e.pageX - pressCarousel.offsetLeft;
            const walk = (x - startX) * 2;
            
            pressCarousel.scrollLeft = startScrollLeft - walk;
            
            scrollPosition = pressCarousel.scrollLeft; 
        });

        const animate = () => {
            if (!isUserScrolling && halfWidth > 0) {
                scrollPosition += scrollSpeed;

                // Reset when we've scrolled past the first set of items
                if (scrollPosition >= halfWidth) {
                    scrollPosition = scrollPosition - halfWidth;
                }

                pressCarousel.scrollLeft = scrollPosition;
            }
            animationFrame = requestAnimationFrame(animate);
        };

        // Start animation
        animationFrame = requestAnimationFrame(animate);

        // Handle user scrolling
        let userScrollTimeout;
        pressCarousel.addEventListener('scroll', () => {
            // Only update if this is a user-initiated scroll
            if (!isUserScrolling && Math.abs(pressCarousel.scrollLeft - scrollPosition) > 2) {
                isUserScrolling = true;
                scrollPosition = pressCarousel.scrollLeft;
            }

            clearTimeout(userScrollTimeout);
            userScrollTimeout = setTimeout(() => {
                if (isUserScrolling) {
                    scrollPosition = pressCarousel.scrollLeft;
                }
            }, 50);
        });

        // Pause on hover
        pressCarousel.addEventListener('mouseenter', () => {
            isUserScrolling = true;
        });

        pressCarousel.addEventListener('mouseleave', () => {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(() => {
                isUserScrolling = false;
                scrollPosition = pressCarousel.scrollLeft;
            }, 500);
        });

        // Recalculate on window resize
        window.addEventListener('resize', () => {
            halfWidth = calculateHalfWidth();
        });

        // Clean up on page unload
        window.addEventListener('beforeunload', () => {
            if (animationFrame) {
                cancelAnimationFrame(animationFrame);
            }
        });
    }

});