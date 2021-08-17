(window.webpackJsonp=window.webpackJsonp||[]).push([[25],{100:function(e,n,t){"use strict";t.r(n),t.d(n,"frontMatter",(function(){return i})),t.d(n,"metadata",(function(){return b})),t.d(n,"toc",(function(){return s})),t.d(n,"default",(function(){return u}));var r=t(3),a=t(7),o=(t(0),t(128)),c=(t(39),t(131)),l=["components"],i={id:"trying",title:"Trying Glean",sidebar_label:"Trying Glean"},b={unversionedId:"trying",id:"trying",isDocsHomePage:!1,title:"Trying Glean",description:"We provide a Docker image containing a pre-built set of Glean binaries",source:"@site/../docs/trying.md",slug:"/trying",permalink:"/docs/trying",editUrl:"https://www.internalfb.com/intern/diffusion/FBS/browse/master/fbcode/glean/website/../docs/trying.md",version:"current",sidebar_label:"Trying Glean",sidebar:"someSidebar",previous:{title:"Introduction",permalink:"/docs/introduction"},next:{title:"Building Glean from Source",permalink:"/docs/building"}},s=[{value:"Running the server",id:"running-the-server",children:[]},{value:"Hyperlink demo",id:"hyperlink-demo",children:[]}],p={toc:s};function u(e){var n=e.components,t=Object(a.a)(e,l);return Object(o.b)("wrapper",Object(r.a)({},p,t,{components:n,mdxType:"MDXLayout"}),Object(o.b)("p",null,"We provide a Docker image containing a pre-built set of Glean binaries\nthat you can try out.  These images are built automatically by a\n",Object(o.b)("a",{parentName:"p",href:"https://github.com/facebookincubator/Glean/blob/master/.github/workflows/glean-docker.yml"},"Github Action"),"."),Object(o.b)("p",null,"Pull the latest demo Docker image (warning, this is around 7GB):"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"docker pull ghcr.io/facebookincubator/glean/demo:latest\n")),Object(o.b)("p",null,"Run it:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"docker run -it -p 8888:8888 ghcr.io/facebookincubator/glean/demo:latest\n")),Object(o.b)("div",{className:"admonition admonition-info alert alert--info"},Object(o.b)("div",{parentName:"div",className:"admonition-heading"},Object(o.b)("h5",{parentName:"div"},Object(o.b)("span",{parentName:"h5",className:"admonition-icon"},Object(o.b)("svg",{parentName:"span",xmlns:"http://www.w3.org/2000/svg",width:"14",height:"16",viewBox:"0 0 14 16"},Object(o.b)("path",{parentName:"svg",fillRule:"evenodd",d:"M7 2.3c3.14 0 5.7 2.56 5.7 5.7s-2.56 5.7-5.7 5.7A5.71 5.71 0 0 1 1.3 8c0-3.14 2.56-5.7 5.7-5.7zM7 1C3.14 1 0 4.14 0 8s3.14 7 7 7 7-3.14 7-7-3.14-7-7-7zm1 3H6v5h2V4zm0 6H6v2h2v-2z"}))),"info")),Object(o.b)("div",{parentName:"div",className:"admonition-content"},Object(o.b)("p",{parentName:"div"},"What's in the image?"),Object(o.b)("ul",{parentName:"div"},Object(o.b)("li",{parentName:"ul"},"A build of Glean, in ",Object(o.b)("inlineCode",{parentName:"li"},"/glean-code")),Object(o.b)("li",{parentName:"ul"},"The ",Object(o.b)("a",{parentName:"li",href:"https://github.com/facebook/flow/"},"flow")," binary, in ",Object(o.b)("inlineCode",{parentName:"li"},"/usr/local/bin/flow")),Object(o.b)("li",{parentName:"ul"},"A checkout of ",Object(o.b)("a",{parentName:"li",href:"https://github.com/facebook/react/"},"react")," in ",Object(o.b)("inlineCode",{parentName:"li"},"/react-code")),Object(o.b)("li",{parentName:"ul"},"A Glean database containing the Flow index of React in ",Object(o.b)("inlineCode",{parentName:"li"},"/gleandb"))))),Object(o.b)("p",null,"Start the Glean ",Object(o.b)("a",{parentName:"p",href:"/docs/shell"},"shell"),":"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"glean-shell --db-root /gleandb --schema /glean-code/glean/schema/source\n")),Object(o.b)("p",null,"You should see:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"Glean Shell, built on <time>, from rev <unknown>\ntype :help for help.\n>\n")),Object(o.b)("p",null,"The demo image contains a pre-generated database containing the\nresults of running the Flow indexer on the React repository:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"> :list\nreact/0 (complete)\n  Created: 2021-05-24T02:42:33Z (30 days, 9 hours ago)\n")),Object(o.b)("p",null,"We can look at the contents:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"react> :db react\nusing database react/0\nreact> :stat\nflow.Declaration.3\n  count: 26756\n  size:  888756 (867.93 kB) 4.8248%\n...\nTotal size: 17.57 MB\n")),Object(o.b)("h2",{id:"running-the-server"},"Running the server"),Object(o.b)("p",null,"Above we showed the shell reading the database from the filesystem\ndirectly. Instead we can run a server that the clients will interact\nwith to make queries:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"glean-server --db-root /gleandb --schema /glean-code/glean/schema/source --port 12345\n")),Object(o.b)("p",null,"And now the shell can connect to the server:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"glean-shell --service localhost:12345\n")),Object(o.b)("p",null,"The commands work exactly the same as with local databases, but now it\nwould also work over the network."),Object(o.b)("h2",{id:"hyperlink-demo"},"Hyperlink demo"),Object(o.b)("p",null,"We have a small demo showing how Glean can enable code navigation. The ",Object(o.b)(c.c,{file:"glean/demo/Hyperlink.hs",mdxType:"SrcFileLink"},"glean-hyperlink")," tool\ncreates a webserver that serves hyperlinked source code using data\nfrom a specified Glean database."),Object(o.b)("p",null,"We can navigate the React source code as follows. First start the\nGlean server:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"glean-server --db-root /gleandb --schema /glean-code/glean/schema/source --port 12345\n")),Object(o.b)("p",null,"Next start the Hyperlink server:"),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre"},"glean-hyperlink --service localhost:12345 --repo react --root /react-code --http 8888\n")),Object(o.b)("p",null,"Now navigate to ",Object(o.b)("inlineCode",{parentName:"p"},"http://localhost:8888")," in your browser, and you\nshould see a list of source files. Click on a file, and navigate\naround the code by clicking on a symbol reference to jump to its\ndefinition.  Try something substantial like\n",Object(o.b)("inlineCode",{parentName:"p"},"react-dom/src/client/ReactDOMComponent.js"),"\n(http://localhost:8888/packages/react-dom/src/client/ReactDOMComponent.js) -\nnote how Glean is accurately linking both local and imported\nsymbols."))}u.isMDXComponent=!0},128:function(e,n,t){"use strict";t.d(n,"a",(function(){return p})),t.d(n,"b",(function(){return m}));var r=t(0),a=t.n(r);function o(e,n,t){return n in e?Object.defineProperty(e,n,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[n]=t,e}function c(e,n){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);n&&(r=r.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),t.push.apply(t,r)}return t}function l(e){for(var n=1;n<arguments.length;n++){var t=null!=arguments[n]?arguments[n]:{};n%2?c(Object(t),!0).forEach((function(n){o(e,n,t[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):c(Object(t)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(t,n))}))}return e}function i(e,n){if(null==e)return{};var t,r,a=function(e,n){if(null==e)return{};var t,r,a={},o=Object.keys(e);for(r=0;r<o.length;r++)t=o[r],n.indexOf(t)>=0||(a[t]=e[t]);return a}(e,n);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(r=0;r<o.length;r++)t=o[r],n.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(a[t]=e[t])}return a}var b=a.a.createContext({}),s=function(e){var n=a.a.useContext(b),t=n;return e&&(t="function"==typeof e?e(n):l(l({},n),e)),t},p=function(e){var n=s(e.components);return a.a.createElement(b.Provider,{value:n},e.children)},u={inlineCode:"code",wrapper:function(e){var n=e.children;return a.a.createElement(a.a.Fragment,{},n)}},d=a.a.forwardRef((function(e,n){var t=e.components,r=e.mdxType,o=e.originalType,c=e.parentName,b=i(e,["components","mdxType","originalType","parentName"]),p=s(t),d=r,m=p["".concat(c,".").concat(d)]||p[d]||u[d]||o;return t?a.a.createElement(m,l(l({ref:n},b),{},{components:t})):a.a.createElement(m,l({ref:n},b))}));function m(e,n){var t=arguments,r=n&&n.mdxType;if("string"==typeof e||r){var o=t.length,c=new Array(o);c[0]=d;var l={};for(var i in n)hasOwnProperty.call(n,i)&&(l[i]=n[i]);l.originalType=e,l.mdxType="string"==typeof e?e:r,c[1]=l;for(var b=2;b<o;b++)c[b]=t[b];return a.a.createElement.apply(null,c)}return a.a.createElement.apply(null,t)}d.displayName="MDXCreateElement"},131:function(e,n,t){"use strict";t.d(n,"b",(function(){return l})),t.d(n,"c",(function(){return i})),t.d(n,"a",(function(){return b}));var r,a=t(0),o=t.n(a),c=t(39);function l(e){return o.a.createElement("a",{href:r+e.file},e.file)}function i(e){return o.a.createElement("a",{href:r+e.file},e.children)}r=Object(c.isInternal)()?"https://www.internalfb.com/code/fbsource/fbcode/":"https://github.com/facebookincubator/Glean/tree/master/";var b=function(e){e.children;var n=e.internal,t=e.external;return Object(c.fbContent)({internal:o.a.createElement("code",null,n),external:o.a.createElement("code",null,t)})}}}]);