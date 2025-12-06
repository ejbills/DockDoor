// DockDoor Website JavaScript

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
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
                        <path d="M8 16a2 2 0 0 0 2-2H6a2 2 0 0 0 2 2zM8 1.918l-.797.161A4.002 4.002 0 0 0 4 6c0 .628-.134 2.197-.459 3.742-.16.767-.376 1.566-.663 2.258h10.244c-.287-.692-.502-1.49-.663-2.258C12.134 8.197 12 6.628 12 6a4.002 4.002 0 0 0-3.203-3.92L8 1.917zM14.22 12c.223.447.481.801.78 1H1c.299-.199.557-.553.78-1C2.68 10.2 3 6.88 3 6c0-2.42 1.72-4.44 4.005-4.901a1 1 0 1 1 1.99 0A5.002 5.002 0 0 1 13 6c0 .88.32 4.2 1.22 6z"/>
                    </svg>
                    Support DockDoor Development
                </div>
                <div class="toast-message">
                    DockDoor is free, but your support helps us continue development. Consider making a small donation to keep this project going.
                </div>
                <div class="toast-actions">
                    <a href="https://www.buymeacoffee.com/keplercafe" class="btn btn-primary toast-btn" target="_blank">Donate</a>
                    <button class="btn btn-outline toast-btn not-now">Not Now</button>
                </div>
            </div>
            <button class="toast-close">&times;</button>
        `;
        
        // Add to container
        toastContainer.appendChild(toast);
        
        // Show the toast after a small delay
        setTimeout(() => {
            toast.classList.add('show');
        }, 300);
        
        // Handle close button click
        const closeBtn = toast.querySelector('.toast-close');
        closeBtn.addEventListener('click', () => {
            hideToast(toast);
        });
        
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
            // Show the donation toast
            createToast();
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