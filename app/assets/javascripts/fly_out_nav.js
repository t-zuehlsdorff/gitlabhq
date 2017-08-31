import Cookies from 'js-cookie';
import bp from './breakpoints';

const HIDE_INTERVAL_TIMEOUT = 300;
const IS_OVER_CLASS = 'is-over';
const IS_ABOVE_CLASS = 'is-above';
const IS_SHOWING_FLY_OUT_CLASS = 'is-showing-fly-out';
let currentOpenMenu = null;
let menuCornerLocs;
let timeoutId;

export const mousePos = [];

export const setOpenMenu = (menu = null) => { currentOpenMenu = menu; };

export const slope = (a, b) => (b.y - a.y) / (b.x - a.x);

let headerHeight = 50;

export const getHeaderHeight = () => headerHeight;

export const canShowActiveSubItems = (el) => {
  const isHiddenByMedia = bp.getBreakpointSize() === 'sm' || bp.getBreakpointSize() === 'md';

  if (el.classList.contains('active') && !isHiddenByMedia) {
    return Cookies.get('sidebar_collapsed') === 'true';
  }

  return true;
};

export const canShowSubItems = () => bp.getBreakpointSize() === 'sm' || bp.getBreakpointSize() === 'md' || bp.getBreakpointSize() === 'lg';

export const getHideSubItemsInterval = () => {
  if (!currentOpenMenu) return 0;

  const currentMousePos = mousePos[mousePos.length - 1];
  const prevMousePos = mousePos[0];
  const currentMousePosY = currentMousePos.y;
  const [menuTop, menuBottom] = menuCornerLocs;

  if (currentMousePosY < menuTop.y ||
      currentMousePosY > menuBottom.y) return 0;

  if (slope(prevMousePos, menuBottom) < slope(currentMousePos, menuBottom) &&
    slope(prevMousePos, menuTop) > slope(currentMousePos, menuTop)) {
    return HIDE_INTERVAL_TIMEOUT;
  }

  return 0;
};

export const calculateTop = (boundingRect, outerHeight) => {
  const windowHeight = window.innerHeight;
  const bottomOverflow = windowHeight - (boundingRect.top + outerHeight);

  return bottomOverflow < 0 ? (boundingRect.top - outerHeight) + boundingRect.height :
    boundingRect.top;
};

export const hideMenu = (el) => {
  if (!el) return;

  const parentEl = el.parentNode;

  el.style.display = ''; // eslint-disable-line no-param-reassign
  el.style.transform = ''; // eslint-disable-line no-param-reassign
  el.classList.remove(IS_ABOVE_CLASS);
  parentEl.classList.remove(IS_OVER_CLASS);
  parentEl.classList.remove(IS_SHOWING_FLY_OUT_CLASS);

  setOpenMenu();
};

export const moveSubItemsToPosition = (el, subItems) => {
  const boundingRect = el.getBoundingClientRect();
  const top = calculateTop(boundingRect, subItems.offsetHeight);
  const isAbove = top < boundingRect.top;

  subItems.classList.add('fly-out-list');
  subItems.style.transform = `translate3d(0, ${Math.floor(top) - headerHeight}px, 0)`; // eslint-disable-line no-param-reassign

  const subItemsRect = subItems.getBoundingClientRect();

  menuCornerLocs = [
    {
      x: subItemsRect.left, // left position of the sub items
      y: subItemsRect.top, // top position of the sub items
    },
    {
      x: subItemsRect.left, // left position of the sub items
      y: subItemsRect.top + subItemsRect.height, // bottom position of the sub items
    },
  ];

  if (isAbove) {
    subItems.classList.add(IS_ABOVE_CLASS);
  }
};

export const showSubLevelItems = (el) => {
  const subItems = el.querySelector('.sidebar-sub-level-items');

  if (!canShowSubItems() || !canShowActiveSubItems(el)) return;

  el.classList.add(IS_OVER_CLASS);

  if (!subItems) return;

  subItems.style.display = 'block';
  el.classList.add(IS_SHOWING_FLY_OUT_CLASS);

  setOpenMenu(subItems);
  moveSubItemsToPosition(el, subItems);
};

export const mouseEnterTopItems = (el) => {
  clearTimeout(timeoutId);

  timeoutId = setTimeout(() => {
    if (currentOpenMenu) hideMenu(currentOpenMenu);

    showSubLevelItems(el);
  }, getHideSubItemsInterval());
};

export const mouseLeaveTopItem = (el) => {
  const subItems = el.querySelector('.sidebar-sub-level-items');

  if (!canShowSubItems() || !canShowActiveSubItems(el) ||
      (subItems && subItems === currentOpenMenu)) return;

  el.classList.remove(IS_OVER_CLASS);
};

export const documentMouseMove = (e) => {
  mousePos.push({
    x: e.clientX,
    y: e.clientY,
  });

  if (mousePos.length > 6) mousePos.shift();
};

export default () => {
  const sidebar = document.querySelector('.sidebar-top-level-items');

  if (!sidebar) return;

  const items = [...sidebar.querySelectorAll('.sidebar-top-level-items > li')];

  sidebar.addEventListener('mouseleave', () => {
    clearTimeout(timeoutId);

    timeoutId = setTimeout(() => {
      if (currentOpenMenu) hideMenu(currentOpenMenu);
    }, getHideSubItemsInterval());
  });

  headerHeight = document.querySelector('.nav-sidebar').offsetTop;

  items.forEach((el) => {
    const subItems = el.querySelector('.sidebar-sub-level-items');

    if (subItems) {
      subItems.addEventListener('mouseleave', () => {
        clearTimeout(timeoutId);
        hideMenu(currentOpenMenu);
      });
    }

    el.addEventListener('mouseenter', e => mouseEnterTopItems(e.currentTarget));
    el.addEventListener('mouseleave', e => mouseLeaveTopItem(e.currentTarget));
  });

  document.addEventListener('mousemove', documentMouseMove);
};
